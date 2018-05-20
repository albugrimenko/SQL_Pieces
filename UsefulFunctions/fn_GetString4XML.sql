SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Description:	Prepares a string for xml usage (aka XMLEncode)
-- NOTE: Implementation is limited to the following prohibites in XML characters:
--		&, <, >, "
--
-- Test: select dbo.fn_GetString4XML('valid & invalid < values & " > must be encoded.')
-- =============================================
CREATE FUNCTION dbo.fn_GetString4XML
(
	@val varchar(MAX)
)
RETURNS varchar(MAX)
AS
BEGIN

	return 
		replace(
			replace(
				replace(
					replace(
						isnull(@val, '')
					, '&', '&amp;')
				, '>', '&gt;')
			, '<', '&lt;')
		, '"', '&quot;')
END
GO

