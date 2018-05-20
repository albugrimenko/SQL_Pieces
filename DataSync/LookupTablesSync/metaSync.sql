SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [meta].[Sync]
	@IsAutoCommit bit = 0

--
-- Synchronizes all tables
-- @IsAutoCommit = 1 will automatically commit all requested changes, otherwaise no modifications will be made.
--

/*
exec meta.Sync @PartnerName=null, @IsAutoCommit=0
exec meta.Sync @PartnerName=null, @IsAutoCommit=1
*/

AS
set nocount on;
set xact_abort on;

SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;

BEGIN TRY

	--------- processing -------
	print '=== Lookup01 ==='
	exec meta.Lookup01 @IsAutoCommit=@IsAutoCommit

END TRY
BEGIN CATCH
    declare @errSeverity int,
            @errMsg nvarchar(2048)
    select  @errSeverity = ERROR_SEVERITY(),
            @errMsg = ERROR_MESSAGE()

    if (xact_state() = 1 or xact_state() = -1)
          ROLLBACK TRAN

    raiserror('[%u]:: %s', 16, 1, @errSeverity, @errMsg)
      
END CATCH

RETURN 1
GO
