SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [meta].[Lookup01]
	@IsAutoCommit bit = 0

--
-- Synchronizes Lookup01 table
--
-- Text to regenerate statements to fill in this procedure' body
/*
--	WARNING: no partner specific statements will be generated!!! It only gets generic lists.
select 'insert into #Lookup01 (ID, Name)' + char(13) + char(10) +
	'values (' + cast(ID as varchar(20)) + ',''' + Name + ''')'
from Lookup01
order by ID
*/

/*
exec meta.Lookup01 @IsAutoCommit=0
exec meta.Lookup01 @IsAutoCommit=1
*/

AS
set nocount on;
set xact_abort on;

declare @n int

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

CREATE TABLE #Lookup01 (
	ID smallint, 
	Name varchar(30)
)

-------- Data - required for TFS-based comparison -------
insert into #Lookup01 (ID, Name)
values (0,'Undefined')
insert into #Lookup01 (ID, Name)
values (1,'Test')
-------- end of Data --------

BEGIN TRY

	--------- processing -------
	declare @Results table ([Action] varchar(6), [ID] int, [Name] varchar(50))

	begin tran
		merge dbo.Lookup01 as t 
		using (
			select ID, Name
			from #Lookup01
		) as s on t.ID = s.ID
		when matched and
			(s.Name != t.Name)
		then
			UPDATE set 
				Name = s.Name
		when not matched by target then 
			INSERT (ID, Name)
			values (s.ID, s.Name)
		when not matched by source then 
			DELETE 
		OUTPUT $action as [Action], isnull(inserted.ID, deleted.ID) as [ID], isnull(inserted.Name, deleted.Name) as [Name]
			into @Results;
	
	if @IsAutoCommit = 1
		commit tran
	else 
		rollback tran

	-- show results
	select * from @Results
	select @n = count(*) from @Results
	if @n = 0 begin
		print '+++ Table Data is in sync - no modifications required. ---'
	end else begin
		print '--- Table Data requires ' + cast(@n as varchar(20)) + ' modifications. ---'
	end
		
END TRY
BEGIN CATCH
    declare @errSeverity int,
            @errMsg nvarchar(2048)
    select  @errSeverity = ERROR_SEVERITY(),
            @errMsg = ERROR_MESSAGE()

    if (xact_state() = 1 or xact_state() = -1)
          ROLLBACK TRAN

	-- print the difference:
	select t.ID, t.Name, 
		[Action] = case when s.ID is null then 'DELETE' else 'UPDATE' end
	from dbo.Lookup01 t 
		left join #Lookup01 s on t.ID = s.ID
	where s.ID is null or 
			(s.Name != t.Name)

    select @errMsg = @errMsg + char(13) + 'Most likely the error is related to DELETE or UPDATE attempt. See Results tab for details.'
    raiserror('Severity %u:: %s', 16, 1, @errSeverity, @errMsg)
      
END CATCH

drop table #Lookup01

RETURN 1
GO
