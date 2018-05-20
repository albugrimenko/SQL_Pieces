SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Converts smalldatetime to a smallint representation
-- NOTE: does NOT support time part of the date; used for dates only
-- Valid dates ranges: 
--		from: 1/1/1900 (-32142) 
--		to: 1/2/2076 (32142)
--
-- Test: select dbo.fmt_Date2SmallInt('2/1/2016')
-- =============================================
CREATE FUNCTION [dbo].[fmt_Date2SmallInt]
( 
	@Date smalldatetime 
)
RETURNS smallint
AS
BEGIN
	RETURN case 
		when @Date < '1/1/1900' then -32142
		when @Date > '1/2/2076' then 32142
		else cast(floor(cast(@Date as money)) as int) - 32142
	end
END
GO
