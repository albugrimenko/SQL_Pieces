CREATE FUNCTION fnEmployee_GetFullDisplayPath(@EntityNodeID hierarchyid)
RETURNS varchar(max)
AS
BEGIN

	declare @EntityLevelDepth smallint,
			@LevelCounter smallint = 0,
			@DisplayPath varchar(max),
			@ParentName varchar(max)

	select	@EntityLevelDepth = NodeID.GetLevel(),
			@DisplayPath = Name
	from Employee 
	where NodeID = @EntityNodeID

	while @LevelCounter < @EntityLevelDepth begin
		set @LevelCounter = @LevelCounter + 1

		select @ParentName = Name
		from Employee
		where NodeID = (
			select NodeID.GetAncestor(@LevelCounter)
			from Employee
			where NodeID = @EntityNodeID
		)

		set @DisplayPath = @ParentName + ' > ' + @DisplayPath
	end

	RETURN @DisplayPath
END
GO
