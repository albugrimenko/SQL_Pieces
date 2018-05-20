SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[util_DefragReindexAuto]
        @DBName varchar(255),
        @TableName varchar(255) = NULL,		--analyses ALL tables when NULL

	@FragThreshold_Defrag int = 10,		--min logical fragmentation percent for "defrag" operation. 
        @FragThreshold_Rebuild int = 40,	--min logical fragmentation percent for "rebuild" operation. 
											--All indices with greater fragmentation must be rebuilt.
	@IsDebug smallint = 0,				--0 do not debug, 1 debug
	@IsSortByName bit = 0,				--sorts results by name when 1
	@ShowRes bit = 1				--shows results when 1

--
-- Shows table(s) indices fragmentation and defrag or rebuild them if neccessary
-- 
-- If @IsDebug = 1, it will print defrag/rebuild statements, BUT NOT execute them.
-- This mode could also be used to print a report of current fragmentation levels
-- If @ShowRes = 0, no results will be shown. Could be useful in a batch mode.
-- If @IsSortByName = 0 results will be sorted by SchemaName, TableName, IndexName, 
--		otherwise by Index Fragmentation Percent in a descending order
--

/*
exec util_DefragReindexAuto @DBName='temp', @IsDebug=1, @IsSortByName=1
*/

AS
set nocount on;

declare @DBID int = DB_ID(@DBName),
		@cmd varchar(1024)

-------------- Checks ------------------
if @DBID is null begin
	raiserror('Invalid database specified %s', 16, 1, @DBName)
	RETURN -1
end
if lower(@DBName) in ('master', 'msdb', 'model', 'tempdb') begin
	raiserror('This procedure should not be used in system databases. %s', 16, 1, @DBName)
	RETURN -1
end

if @FragThreshold_Rebuild < 0 OR @FragThreshold_Rebuild > 100 or @FragThreshold_Rebuild is null begin
	raiserror('FragThreshold_Rebuild must be between 0 and 100 (supplied value is %d).', 16, 1, @FragThreshold_Rebuild)
	RETURN -1
end
-------------- Checks ------------------

create table #tlist (
	--ID int identity(1,1) not null,
	SchemaName varchar(255),
	TableName varchar(255),
	IndexName varchar(255),
	IndexFragmPercent money,
	IndexPageCount money,
	ActionPerformed varchar(2048)
)

select @cmd = 'USE ' + rtrim(@DBName) + '
	select 
		SchemaName = dbschemas.[name],
		TableName = dbtables.[name],
		IndexName = dbindexes.[name],
		IndexFragmPercent = indexstats.avg_fragmentation_in_percent,
		IndexPageCount = indexstats.page_count
	from sys.dm_db_index_physical_stats(' + cast(@DBID as varchar(20)) + ', NULL, NULL, NULL, NULL) AS indexstats
		join ' + rtrim(@DBName) + '.sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
		join ' + rtrim(@DBName) + '.sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
		join ' + rtrim(@DBName) + '.sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id] 
			and indexstats.index_id = dbindexes.index_id
	where indexstats.database_id = ' + cast(@DBID as varchar(20)) + '
		and dbindexes.type > 0 '
		+ case when @TableName is null then '' else 'and dbtables.[name]=''' + @TableName + ''' ' end + 
	'order by SchemaName, TableName, IndexName'

--print (@cmd)

insert into #tlist (SchemaName, TableName, IndexName, IndexFragmPercent, IndexPageCount)
exec(@cmd)

------------- processing
declare @cr CURSOR,
		@sName varchar(255),
		@tName varchar(255),
		@iName varchar(255),
		@iFragmPercent money,
		@action varchar(50)

set @cr = CURSOR for
	select 
		SchemaName = rtrim(SchemaName), 
		TableName = rtrim(TableName), 
		IndexName = rtrim(IndexName), 
		IndexFragmPercent
	from #tlist

open @cr
fetch next from @cr into @sName, @tName, @iName, @iFragmPercent
while @@fetch_status = 0 begin
	set @action = ''
	if @iFragmPercent >= @FragThreshold_Rebuild begin
		-- rebuild
		select @cmd = 'USE ' + rtrim(@DBName) + ' ALTER INDEX [' + @iName + '] ON [' + @sName + '].[' + @tName + '] REBUILD PARTITION = ALL WITH (ONLINE = ON)'
		select @action = 'Rebuilt'
	end else if @iFragmPercent >= @FragThreshold_Defrag begin
		-- defrag
		select @cmd = 'USE ' + rtrim(@DBName) + ' ALTER INDEX [' + @iName + '] ON [' + @sName + '].[' + @tName + '] REORGANIZE WITH (LOB_COMPACTION = ON)'
		select @action = 'Defragmented'
	end else begin
		select @cmd = '', @action = 'Skipped (no action required)'
	end

	begin try
		if len(@cmd) > 0 and @IsDebug = 1
			print @cmd
		else if len(@cmd) > 0 and @IsDebug = 0
			exec(@cmd)

		select @action = @action + case
			when @IsDebug = 0 then ': OK'
			else ': <none - debug mode>'
		end
	end try
	begin catch
		select @action = @action + ': ERROR (' + error_message() + ')'
	end catch

	update #tlist set ActionPerformed = @action
	where SchemaName=@sName and TableName=@tName and IndexName=@iName

	fetch next from @cr into @sName, @tName, @iName, @iFragmPercent
end

close @cr 
deallocate @cr

------------- updating results & report
if @ShowRes = 1 begin
	create table #t2 (
		SchemaName varchar(255),
		TableName varchar(255),
		IndexName varchar(255),
		IndexFragmPercent money,
		IndexPageCount money
	)

	select @cmd = 'USE ' + rtrim(@DBName) + '
		select 
			SchemaName = dbschemas.[name],
			TableName = dbtables.[name],
			IndexName = dbindexes.[name],
			IndexFragmPercent = indexstats.avg_fragmentation_in_percent,
			IndexPageCount = indexstats.page_count
		from sys.dm_db_index_physical_stats(' + cast(@DBID as varchar(20)) + ', NULL, NULL, NULL, NULL) AS indexstats
			join ' + rtrim(@DBName) + '.sys.tables dbtables on dbtables.[object_id] = indexstats.[object_id]
			join ' + rtrim(@DBName) + '.sys.schemas dbschemas on dbtables.[schema_id] = dbschemas.[schema_id]
			join ' + rtrim(@DBName) + '.sys.indexes AS dbindexes ON dbindexes.[object_id] = indexstats.[object_id] 
				and indexstats.index_id = dbindexes.index_id
		where indexstats.database_id = ' + cast(@DBID as varchar(20)) + '
			and dbindexes.type > 0 '
			+ case when @TableName is null then '' else 'and dbtables.[name]=''' + @TableName + ''' ' end + 
		'order by SchemaName, TableName, IndexName'

	insert into #t2 (SchemaName, TableName, IndexName, IndexFragmPercent, IndexPageCount)
	exec(@cmd)

	select 
		t.SchemaName,
		t.TableName,
		t.IndexName,
		t.IndexPageCount,
		t.IndexFragmPercent,
		New_IndexFragmPercent = r.IndexFragmPercent,
		t.ActionPerformed
	from #tlist t
		join #t2 r on t.SchemaName = r.SchemaName and t.TableName = r.TableName and t.IndexName = r.IndexName 
	order by 
		case when @IsSortByName = 0 then t.IndexFragmPercent else 1 end desc,
		t.SchemaName, t.TableName, t.IndexName
end

RETURN 1
GO
