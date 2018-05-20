-- ================= Get all tables in File Groups DETAILED ==============
-- sys.allocation_units: container_id
--		ID of the storage container associated with the allocation unit.
--		If type = 1 or 3, container_id = sys.partitions.hobt_id.
--		If type is 2, then container_id = sys.partitions.partition_id.
--		0 = Allocation unit marked for deferred drop
--	type - Type of allocation unit:
--		0 = Dropped
--		1 = In-row data (all data types, except LOB data types)
--		2 = Large object (LOB) data (text, ntext, image, xml, large value types, and CLR user-defined types)
--		3 = Row-overflow data
-- ========================================================================

declare
	@TableName nvarchar(50) = NULL -- filter by table name (used with 'like')

set nocount on;

declare @ObjID int

if @TableName is not null 
	select @ObjID = OBJECT_ID(@TableName, N'U')

; with fg as (
	select data_space_id, name, type_desc,
		Partition_Function = '', Partition_Num = 0
	from sys.filegroups
	union all
	select data_space_id = ps.data_space_id, ps.name, 
		type_desc = 'partitioned',
		Partition_Function = isnull(pf.name, ''), 
		Partition_Num = fanout
	from sys.partition_schemes ps
		left join sys.partition_functions pf on ps.function_id = pf.function_id
)
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
	Size_MB = cast(a.total_pages * 8./1024 as money),
	--Partition_ID = p.partition_id, 
	Partition_Number = p.partition_number, 
	Partition_Compression = p.data_compression_desc,
	FileGroupName = fg.name,
	FileGroupType = fg.type_desc,
	Partition_Function = fg.Partition_Function,
	Partition_Num = fg.Partition_Num
from sys.indexes i 
	join sys.partitions p on p.object_id = i.object_id and p.index_id = i.index_id 
	join sys.allocation_units a on 
		(a.type in (1,3) and a.container_id=p.hobt_id) or (a.type=2 and a.container_id=p.partition_id)
	join sys.objects o on o.object_id = p.object_id
	left join fg on fg.data_space_id = i.data_space_id 
where o.type = 'U' -- User Created Tables
	and (@ObjID is null or i.object_id = @ObjID)
order by o.[name], i.type_desc, i.name

