SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Parses list of comma separated Items into @Items table
-- Test: select * from fn_CSV2Table('test,123,next, abcd , last')
-- =============================================
CREATE FUNCTION [dbo].[fn_CSV2Table] 
(	
	@ItemsStr text -- comma separated list of values to be parsed
)
RETURNS @Items TABLE (Item varchar(50))
AS

begin
	declare 
			@ItemsList varchar(8000),
			@Item varchar(50), 
			@Pos int
	if datalength(@ItemsStr) <= 8000 --otherwise returns empty table
	begin
		select @ItemsList = LTRIM(RTRIM(cast(@ItemsStr as varchar(8000))))+ ','
		select @Pos = CHARINDEX(',', @ItemsList, 1)
		if REPLACE(@ItemsList, ',', '') <> '' begin
			while @Pos > 0 begin
				select @Item = LTRIM(RTRIM(LEFT(@ItemsList, @Pos - 1)))
				if @Item <> '' begin
					insert into @Items (Item) values (CAST(@Item AS varchar(50)))
				end
				select @ItemsList = RIGHT(@ItemsList, LEN(@ItemsList) - @Pos)
				select @Pos = CHARINDEX(',', @ItemsList, 1)
			end
		end	
	end
	return 
end

GO
