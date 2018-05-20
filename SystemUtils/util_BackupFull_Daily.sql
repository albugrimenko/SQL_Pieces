SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[util_BackupFull_Daily]
	@DBName sysname,
	@BackupPath nvarchar(255) = N'C:\MSSQL\BACKUP\'

--
-- Auto adds day name to the end of file name to keep daily backups for the last week.
-- It allows to recycle backups and always preserve the whole last week set of backups.
-- BACKUP DATABASE [ABC] TO [ABC_Tu] ...
--

AS
set nocount on;

------------ Checks ---------
if @BackupPath is null or len(@BackupPath) < 1 begin
	raiserror('util_BackupFull_Daily:: BackupPath is required', 16, 1)
	RETURN -1
end

if @DBName is null or len(@DBName) < 1 begin
	raiserror('util_BackupFull_Daily:: DBName is required', 16, 1)
	RETURN -1
end
------------ Checks ---------

declare @DaySuffix varchar(2) = DATENAME(weekday, getdate())

select @BackupPath = @BackupPath 
	+ case when right(@BackupPath, 1) != '\' then '\' else '' end
	+ @DBName + '_' + @DaySuffix + '.bak'

-------------------- Backup Database --------------------------------
BACKUP DATABASE @DBName to DISK=@BackupPath WITH INIT, NOUNLOAD, NOSKIP, STATS = 100, NOFORMAT

RETURN 1
GO
