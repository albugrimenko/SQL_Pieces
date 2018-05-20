SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Converts int to date representation
-- Valid dates ranges matches range for date data type: 
--		from: 1753-01-01 (-85832) 
--		to: 9999-12-31 (2926321)
--
-- Test: select dbo.fmt_Int2DATE(10257)
-- =============================================
CREATE FUNCTION [dbo].[fmt_Int2DATE]
( 
	@Date int
)
RETURNS datetime
AS
BEGIN
	RETURN cast(@Date + 32142 as datetime)
END
GO
