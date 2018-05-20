SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	returns last N most expensive queries
--		Based on "No more guessing" seminar by Adam Machanic
--
-- Test: exec stat_MostExpensiveQueries @SortBy='time'
-- =============================================
CREATE PROCEDURE dbo.stat_MostExpensiveQueries
	@TopN int = 30,					-- # of top records returned
	@SortBy varchar(20) = 'reads'	-- defines sorting order. Valid values are: reads, writes, time

AS
set nocount on;

set @SortBy = lower(rtrim(ltrim(@SortBy)))
if @SortBy is null or @SortBy not in ('reads', 'writes', 'time') 
	select @SortBy = 'reads'

select top (@TopN) 
	[Query Text] = substring(qt.TEXT, (qs.statement_start_offset/2)+1,
		((CASE qs.statement_end_offset 
			WHEN -1 THEN DATALENGTH(qt.TEXT) 
			ELSE qs.statement_end_offset 
		END - qs.statement_start_offset)/2)+1),
	[# Executions] = qs.execution_count,
	[Total Logical Reads] = qs.total_logical_reads, 
	[Last Logical Reads] = qs.last_logical_reads,
	[Total Logical Writes] = qs.total_logical_writes, 
	[Last Logical Writes] = qs.last_logical_writes,
	[Total Worker Time] = qs.total_worker_time,
	[Last Worker Time] = qs.last_worker_time,
	[Total Elapsed Time (s)] = qs.total_elapsed_time/1000000,
	[Last Elapsed Time (s)] = qs.last_elapsed_time/1000000,
	[Max Elapsed Time (s)] = qs.max_elapsed_time/1000000,
	[Last Exec Time] = qs.last_execution_time,
	[Last # Rows] = qs.last_rows,
	[Query Plan] = qp.query_plan
from sys.dm_exec_query_stats qs
	cross apply sys.dm_exec_sql_text(qs.sql_handle) qt
	cross apply sys.dm_exec_query_plan(qs.plan_handle) qp
order by 
	case 
		when @SortBy = 'reads' then qs.total_logical_reads 
		when @SortBy = 'writes' then qs.total_logical_writes 
		when @SortBy = 'time' then qs.total_worker_time 
		else qs.total_logical_reads 
	end
	desc

RETURN 1
GO
