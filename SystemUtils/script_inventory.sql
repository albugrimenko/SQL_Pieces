-- ================= INVENTORY ==============
-- Gets basic info about SQL Server and available resources
-- ===========================================
; with s as (
	select cpu_count, hyperthread_ratio, RAM_GB = null, ver_OS = null, ver_SQL = null
	from sys.dm_os_sys_info
	union all
	select  cpu_count = null, hyperthread_ratio = null,
		RAM_GB = total_physical_memory_kb/1024/1024,
		ver_OS = null, ver_SQL = null
	from sys.dm_os_sys_memory
	union all
	select cpu_count = null, hyperthread_ratio = null, RAM_GB = null, 
		ver_OS = case
			when windows_release = 6.0 then 'Win 2008'
			when windows_release = 6.1 then 'Win 2008 R2'
			when windows_release = 6.2 then 'Win 2012'
			when windows_release = 6.3 then 'Win 2012 R2'
			when windows_release >= 10 then 'Win 2016'
		end,
		ver_SQL = @@version
	from sys.dm_os_windows_info
)
select 
	CPU_cnt = max(cpu_count), 
	hyperthread_ratio = max(hyperthread_ratio),
	RAM_GB = max(RAM_GB), 
	ver_OS = max(ver_OS), 
	ver_SQL = max(ver_SQL)
from s;
