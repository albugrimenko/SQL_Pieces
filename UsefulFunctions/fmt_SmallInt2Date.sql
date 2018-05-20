SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Converts smallint to smalldatetime representation
-- NOTE: does NOT support time part of the date; used for dates only
-- Valid dates ranges: 
--		from: 1/1/1900 (-32142) 
--		to: 1/2/2076 (32142)
--
-- Test: select dbo.fmt_SmallInt2Date(10257)
-- =============================================
CREATE FUNCTION [dbo].[fmt_SmallInt2Date]
( 
	@Date smallint
)
RETURNS smalldatetime
AS
BEGIN
	RETURN cast(cast(@Date as int) + 32142 as smalldatetime)
END
GO