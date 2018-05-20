SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_who_active]
	@IsSortByID bit = 0

--
-- Shows all active connections to the server
-- If @IsSortByID = 1 all processed will be sorted by process id,
--	otherwise recordset sorted by database name and user login
--

AS
set nocount on;

DECLARE @spid int,
		@Result int

---------------- Get SQL Statement for each connection -----------------------------
DECLARE @sqlstring varchar(250),
		@cr CURSOR
CREATE TABLE #temp (
	ID int IDENTITY (0, 1) NOT NULL,
	EventType nvarchar(30) NULL, 
	Parameters int NULL, 
	EventInfo nvarchar(4000),
	PID int NULL
)
set @cr = CURSOR forward_only FOR
	select spid
	from master.dbo.sysprocesses sproc (nolock)
		join master.dbo.sysdatabases sdb (nolock) on sproc.dbid = sdb.dbid
	where spid > 5
		and (lower(cmd) <> 'awaiting command' and sproc.cmd <> 'DB MIRROR')
		/** Inactive and system processes are excluded ***/
OPEN @cr
FETCH NEXT FROM @cr INTO @spid
WHILE @@fetch_status = 0 BEGIN
	SET @sqlstring = 'DBCC INPUTBUFFER (' + CAST(@spid AS CHAR(4)) + ') WITH NO_INFOMSGS'
	
	INSERT #temp (EventType, Parameters, EventInfo)
	EXEC (@sqlstring)
	
	select @Result = scope_identity()
	update #temp set PID = @spid where ID = @Result
	FETCH NEXT FROM @cr INTO @spid
END
CLOSE @cr
DEALLOCATE @cr

------------------------ Get statistical process information ------------------------------
SELECT --distinct
	sproc.spid,
	DBName = cast(isnull(sdb.name, '') as varchar(50)),
	Login = cast(sproc.loginame as varchar(50)),
	status = left(sproc.status,10),
	sproc.cmd,
	sproc.blocked,
	cpu = max(sproc.cpu),
	physical_io = max(sproc.physical_io),
	memusage = max(sproc.memusage),
	hostname = cast(sproc.hostname as varchar(50)),
	program_name = cast(sproc.program_name as varchar(50)),
	EventType = t.EventType,
	EventInfo = rtrim(cast(t.EventInfo as varchar(150))) + case
		when len(rtrim(isnull(t.EventInfo, ''))) > 150 then '...'
		else ' '
	end,
	waittime = max(sproc.waittime),
	waitresource = convert(varchar(16), sproc.waitresource),
	open_tran = sum(sproc.open_tran),
	WindowsProcNumber = count(sproc.kpid)
	--WindowsProcID = sproc.kpid
FROM master.dbo.sysprocesses sproc (nolock)
	left join master.dbo.sysdatabases sdb (nolock) on sproc.dbid = sdb.dbid
	left join #temp t (nolock) on sproc.spid = t.PID
group by sproc.spid, cast(isnull(sdb.name, '') as varchar(50)), cast(sproc.loginame as varchar(50)),
	sproc.status, sproc.cmd, sproc.blocked, cast(sproc.hostname as varchar(50)), 
	cast(sproc.program_name as varchar(50)),
	t.EventType, t.EventInfo, sproc.waitresource
order by 
	case when @IsSortByID = 1 then sproc.spid else 1 end, 
	DBName, Login, sproc.spid

DROP TABLE #temp

RETURN 1
GO
