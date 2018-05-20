-- =============================================
-- Description:	gets list of all tables along with table and index sizes.
--
-- Purpose: find biggest tables (potential candidates for partitioning)
-- =============================================

declare
	@TableName nvarchar(50) = NULL, -- filter by table name (used with 'like')
	@SortBy varchar(20) = 'rows'		-- valid values: rows, size, name

set nocount on;

declare @ObjID int

if @TableName is not null 
	select @ObjID = OBJECT_ID(@TableName, N'U')
select @SortBy = lower(nullif(rtrim(@SortBy), ''))


;with t as (
	select
		TableName = QUOTENAME(OBJECT_SCHEMA_NAME(t.object_id)) + '.'
					+ QUOTENAME(OBJECT_NAME(t.object_id)),
		IndexName = '',
		IndexType = '',
		AllocType = '<TOTAL>',
		Rows_Count = max(s.row_count),
		Pages_UsedCount = sum(s.used_page_count),
		Pages_ReservedCount = sum(s.reserved_page_count),
		Pages_TotalCount = sum(s.reserved_page_count+s.used_page_count),
		Size_MB = cast(sum(s.reserved_page_count+s.used_page_count) * 8./1024 as money)
	from sys.dm_db_partition_stats s 
		join sys.tables t on s.object_id = t.object_id
		join sys.objects o on o.object_id = t.object_id
	where o.type = 'U' -- User Created Tables
		and (@ObjID is null or t.object_id = @ObjID)
	group by t.object_id
),
i as (
	select 
		TableName = QUOTENAME(OBJECT_SCHEMA_NAME(i.object_id)) + '.'
					+ QUOTENAME(OBJECT_NAME(i.object_id)),
		IndexName = isnull(i.name, ''),
		IndexType = i.type_desc,
		AllocType = a.type_desc,
		Rows_Count = p.[rows],
		Pages_UsedCount = a.used_pages,
		Pages_ReservedCount = case when a.total_pages > a.used_pages then a.total_pages - a.used_pages else 0 end,
		Pages_TotalCount = a.total_pages,
		Size_MB = cast(a.total_pages * 8./1024 as money)
	from sys.indexes i 
		join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id 
		join sys.allocation_units a on 
			(a.type in (1,3) and a.container_id=p.hobt_id) or (a.type=2 and a.container_id=p.partition_id)
		join sys.objects o on o.object_id = p.object_id
	where o.type = 'U' -- User Created Tables
		and (@ObjID is null or i.object_id = @ObjID)
)
select * from (
	select TableName, IndexName, IndexType, AllocType,
		Rows_Count, Pages_UsedCount, Pages_ReservedCount, Pages_TotalCount, Size_MB
	from t

	union all

	select TableName, IndexName, IndexType, AllocType,
		Rows_Count, Pages_UsedCount, Pages_ReservedCount, Pages_TotalCount, Size_MB
	from i
) a
order by 
	case when @SortBy = 'size' then Size_MB else null end desc,
	case when @SortBy = 'rows' then Rows_Count else null end desc,
	TableName, IndexName
