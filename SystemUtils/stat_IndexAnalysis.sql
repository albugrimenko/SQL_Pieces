SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description: gets basic statistics about indexes, including data on missing and not used indexes.
-- NOTE: all data collected by SQL Server since last restart.
--
-- Test: exec stat_IndexAnalysis @Mode='stat'
-- =============================================
CREATE PROCEDURE [dbo].[stat_IndexAnalysis]
	@Mode varchar(20) = 'stat',	-- stat, report, notused, missing, details
	@DBName varchar(50) = NULL,	-- filter by databse name
	@TableName varchar(50) = NULL -- filter by table name (used with 'like')

AS
set nocount on;

set @Mode = lower(rtrim(ltrim(@Mode)))
if @Mode is null or @Mode not in ('stat', 'report', 'notused', 'missing', 'details') begin
	select @Mode = 'stat'
	print '--- Valid values for @Mode are ---'
	print 'stat, report, notused, missing, details'
end

select @DBName = nullif(@DBName, ''), @TableName = nullif(@TableName, '')

if @TableName is not null
	set @TableName = '%' + @TableName + '%'

declare @db_name sysname,
		@db_id int,
		@cr CURSOR,
		@cmd varchar(2048)

create table #indexstats (
	DBID int, DBName sysname,
	[Table Name] varchar(255),
	[Index Name] varchar(255),
	[Index Type] varchar(255),
	[Is PK] bit,
	[Is Uniq] bit,
	[Rows Num] bigint,
	[Reads] bigint,
	[Writes] bigint,
	[Pages Total] bigint,
	[Pages Used] bigint,
	[Rows Modified since Stat Update] bigint,
	[Fragm Percent] money
)

--------------- collect data ----------------
if @Mode != 'missing' begin
	set @cr = CURSOR for
		select database_id, name
		from sys.databases
		where is_read_only = 0	-- READ_WRITE
			and state = 0	-- ONLINE
			and database_id > 4		-- exclude system databses
			and (@DBName is null or name = @DBName)

	print 'Getting data for:'
	open @cr
	fetch next from @cr into @db_id, @db_name
	while @@fetch_status = 0 begin
		print '  - ' + rtrim(@db_name)

		select @cmd = 'use ' + rtrim(@db_name) + '  
			insert into #indexstats
			select 
				DBID = ' + cast(@db_id as varchar(20)) + ', 
				DBName = ''' + rtrim(@db_name) + ''', 
				[Table Name] = ''[' + rtrim(@db_name) + '].'' 
					+ QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id)) + ''.'' 
					+ QUOTENAME(OBJECT_NAME(i.object_id)),
				[Index Name] = isnull(QUOTENAME(si.name),''''),
				[Index Type] = i.type_desc,
				[Is PK] = i.is_primary_key,
				[Is Uniq] = i.is_unique,
				[Rows Num] = isnull(si.rows, 0),
				[Reads] = s.Reads,
				[Writes] = s.Writes,
				[Pages Total] = isnull(si.used,0) + isnull(si.reserved,0),
				[Pages Used] = isnull(si.used,0),
				[Rows Modified since Stat Update] = isnull(si.rowmodctr,0),
				IndexFragmPercent = isnull(cast(indexstats.avg_fragmentation_in_percent as money),0)
			from ' + rtrim(@db_name) + '.sys.indexes i
				left join ' + rtrim(@db_name) + '.sys.sysindexes si on i.object_id = si.id and i.index_id = si.indid
				left join (
					select index_id, object_id, 
						Reads = sum(isnull(user_seeks,0) + isnull(user_scans,0) + isnull(user_lookups,0)),
						Writes = sum(isnull(user_updates,0))
					from sys.dm_db_index_usage_stats 
					group by index_id, object_id
					) s on i.index_id = s.index_id AND s.object_id = i.object_id  
				left join (
					select 
						object_id, 
						index_id,
						avg_fragmentation_in_percent = max(avg_fragmentation_in_percent)
					from sys.dm_db_index_physical_stats(' + cast(@db_id as varchar(20)) + ', NULL, NULL, NULL, NULL)
					group by object_id, index_id
				) indexstats
					on i.object_id = indexstats.object_id and i.index_id = indexstats.index_id
			where OBJECTPROPERTY(i.object_id,''IsUserTable'') = 1
				and i.type > 0	-- exclude system heap
			'
			--print @cmd
			exec (@cmd)

		fetch next from @cr into @db_id, @db_name
	end
	close @cr
	deallocate @cr

	--  get rid of system tables marked as "user table"
	delete #indexstats where [Table Name] like '%dtproperties%'
end

------------ reports -----------
if @Mode = 'details' begin
	select *
	from #indexstats
	order by DBName, [Table Name], [Rows Num] desc, [Index Name]
end else if @Mode = 'stat' begin
	; with i as (
		select DBID, DBName,
			iTotal = count(*),
			iNotUsed = sum(case 
				when [Is PK] = 0 and [Is Uniq] = 0 and [Index Type] = 'NONCLUSTERED' and [Reads] = 0 then 1
				else 0
			end),
			iRequiredRebuid = sum(case when [Fragm Percent] > 40 then 1 else 0 end),
			iRequiredDefrag = sum(case when [Fragm Percent] >= 10 and [Fragm Percent] <= 40 then 1 else 0 end),
			iNotRequired = sum(case when [Fragm Percent] > 0 and [Fragm Percent] < 10 then 1 else 0 end)
		from #indexstats i
		group by DBID, DBName
	),
	imis as (
		select DBID = database_id,
			iMissing = count(*)
		from sys.dm_db_missing_index_details det
		where det.database_id in (select distinct DBID from #indexstats)
		group by database_id
	)
	select i.DBID,
		i.DBName,
		[Total Index Count] = i.iTotal,
		[Not Used Count] = i.iNotUsed,
		[Missing Count] = isnull(imis.iMissing, 0),
		[Fragm < 10%] = isnull(iNotRequired, 0),
		[10% < Fragm < 40% (Defrag)] = isnull(iRequiredDefrag, 0),
		[Fragm > 40% (Rebuild)] = isnull(iRequiredRebuid, 0)
	from i	
		left join imis on i.DBID = imis.DBID
	order by i.DBName
end else if @Mode = 'missing' begin
	select 
		[Table Name] = statement, 
		[Average % Benefit] = mis.avg_user_impact,
		[Equality Columns] = mi.equality_columns,
		[Inequality Columns] = mi.inequality_columns,
		[Included Columns] = mi.included_columns,

		[Unique Compiles] = mis.unique_compiles,
		[User Seeks] = mis.user_seeks, 
		[User Scans] = mis.user_scans,
		[Last User Seek] = mis.last_user_seek,
		[Last User Scan] = mis.last_user_scan,
		[Statement] = 'CREATE NONCLUSTERED INDEX <IX_xxx> ON ' + statement + ' (' 
			+ isnull(mi.equality_columns, '') 
			+ case when mi.equality_columns is not null and mi.inequality_columns is not null then ', ' else '' end
			+ isnull(mi.inequality_columns, '') + ')'
			+ case when mi.included_columns is not null then ' INCLUDE (' + mi.included_columns + ')' else '' end
		--mis.group_handle
	from sys.dm_db_missing_index_details mi
		join sys.dm_db_missing_index_groups mig on mi.index_handle = mig.index_handle
		join sys.dm_db_missing_index_group_stats mis on mig.index_group_handle = mis.group_handle
	where (@DBName is null or statement like '[[]' + @DBName + '%')
		and (@TableName is null or statement like @TableName)
	order by mis.last_user_scan desc, mis.user_seeks desc, mis.unique_compiles desc
end else begin
	select *,
		[Statement] = case 
			when @Mode = 'notused' then 'DROP INDEX ' + [Index Name] + ' ON ' + [Table Name]
			else ''
		end
	from #indexstats
	where (isnull(@Mode, '') in ('', 'report')
		or 
		(@Mode = 'notused' and [Is PK] = 0 and [Is Uniq] = 0 and [Index Type] = 'NONCLUSTERED' and [Reads] = 0))
	order by [Table Name], [Index Name]
end

drop table #indexstats

RETURN 1
GO
