SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Converts date to an int representation
-- Valid dates ranges matches range for date data type: 
--		from: 1753-01-01 (-85832) 
--		to: 9999-12-31 (2926321)
--
-- Test: select dbo.fmt_DATE2Int('2/1/2016')
-- =============================================
CREATE FUNCTION [dbo].[fmt_DATE2Int]
( 
	@Date date
)
RETURNS int
AS
BEGIN
	RETURN (convert(int,cast(@Date as datetime)) - 32142) 
END
GO
