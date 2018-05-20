SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	returns list of open connections to all databses on the server
--
-- Test: exec stat_OpenConnections @Mode='det'
-- =============================================
CREATE PROCEDURE dbo.stat_OpenConnections
	@Mode varchar(20) = 'stat'	-- defines result set detalization. Valid values are: stat, detailed, det

AS
set nocount on;

set @Mode = lower(rtrim(ltrim(@Mode)))
if @Mode is null or @Mode not in ('stat', 'detailed', 'det') 
	select @Mode = 'stat'

if @Mode in ('detailed', 'det') begin
	select 
		DBName = sdb.name,
		s.status,
		s.program_name,
		s.login_name,
		s.host_name,
		c.session_id,
		c.connect_time,
		c.net_transport,
		c.protocol_type,
		c.net_packet_size,
		c.auth_scheme,
		c.num_reads, c.num_writes,
		sproc.open_tran, blocked_spid = sproc.blocked
	from sys.dm_exec_sessions s (nolock) 
		join sys.dm_exec_connections c (nolock) on s.session_id = c.session_id
		join sys.sysprocesses sproc (nolock) on s.session_id = sproc.spid
		join sys.sysdatabases sdb (nolock) on sproc.dbid = sdb.dbid
	where s.is_user_process = 1
	order by s.status, s.program_name, s.login_name, s.host_name
end else begin
	select 
		DBName = sdb.name,
		s.program_name,
		s.login_name,
		[# Connections] = count(s.session_id),
		[# Running] = sum(case when s.status = 'running' then 1 else 0 end),
		[# Sleeping] = sum(case when s.status = 'sleeping' then 1 else 0 end),
		[# Dormant] = sum(case when s.status = 'dormant' then 1 else 0 end),	-- Session has been reset because of connection pooling and is now in prelogin state.
		[# Preconnect] = sum(case when s.status = 'preconnect' then 1 else 0 end),
		[Open Tran] = sum(sproc.open_tran),
		[# Blocks] = sum(case when sproc.blocked > 0 then 1 else 0 end)
	from sys.dm_exec_sessions s (nolock) 
		join sys.dm_exec_connections c (nolock) on s.session_id = c.session_id
		join sys.sysprocesses sproc (nolock) on s.session_id = sproc.spid
		join sys.sysdatabases sdb (nolock) on sproc.dbid = sdb.dbid
	where s.is_user_process = 1
	group by sdb.name, s.program_name, s.login_name with rollup
	order by sdb.name, s.program_name, s.login_name
end

RETURN 1
GO
