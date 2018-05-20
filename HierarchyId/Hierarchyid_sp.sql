CREATE PROCEDURE [dbo].[Employee_Get]

AS
set nocount on 

	select ID,
			NodeID,
			NodeLevel,
			Name,
			Title,
			NodeIDPath = NodeID.ToString(),
			FamilyTree = dbo.fnEmployee_GetFullDisplayPath(NodeID)
	from Employee
	where ID > 0
	order by NodeID.ToString(), Name

RETURN 1
GO
CREATE PROCEDURE [dbo].[Employee_Put]
	@Name varchar(20),
	@Title varchar(20) = null,
	@ParentName varchar(20) = null

/*
-- top level
Employee_Put @Name = 'Dave', @Title = 'Boss', @ParentName = null

-- with parent
Employee_Put @Name = 'Amy', @Title = 'Manager', @ParentName = 'Dave'

*/

AS
set nocount on;
set xact_abort on;

declare @d smalldatetime = getdate();

BEGIN TRY

	declare @oldNodeID hierarchyid,
			@oldParentNodeID hierarchyid,
			@newParentNodeID hierarchyid

	select @oldNodeID = NodeID, @oldParentNodeID = NodeID.GetAncestor(1) from Employee where Name = @Name
	if @ParentName is not null begin
		select @newParentNodeID = NodeID from Employee where Name = @ParentName
		if @newParentNodeID is null begin
			raiserror('Parent record cannot be found.', 16, 1)
			RETURN -1
		end
		if @oldNodeID is not null and @oldParentNodeID = @newParentNodeID
			set @newParentNodeID = null		-- no structure update required
	end else begin
		if @oldNodeID is null
			-- top level
			select @newParentNodeID = hierarchyid::GetRoot()	--NodeID from Employee where ID = 0	--hierarchyid::GetRoot()
		else
			-- no update required
			select @newParentNodeID = null
	end

	if @newParentNodeID is not null begin
		select @newParentNodeID = @newParentNodeID.GetDescendant(max(NodeID), NULL)
		from Employee
		where NodeID.GetAncestor(1) = @newParentNodeID;
	end

	set transaction isolation level SERIALIZABLE;
	BEGIN TRAN

		if @oldNodeID is not null begin
			-- update
			update Employee set
				Name = isnull(@Name, Name),
				Title = isnull(@Title, Title)
			where NodeID = @oldNodeID

			-- update parent
			if @newParentNodeID is not null begin
				update Employee set
					NodeID = NodeID.GetReparentedValue(@oldNodeID, @newParentNodeID)
				where NodeID.IsDescendantOf(@oldNodeID) = 1
			end
		end else begin
			-- Add new
			insert into Employee (NodeID, Name, Title)
			values (@newParentNodeID, @Name, @Title)
		end

	COMMIT TRAN

END TRY
BEGIN CATCH
    declare @errSeverity int,
            @errMsg nvarchar(2048)
    select  @errSeverity = ERROR_SEVERITY(),
            @errMsg = ERROR_MESSAGE()

    -- Test XACT_STATE:
        -- If 1, the transaction is committable.
        -- If -1, the transaction is uncommittable and should be rolled back.
        -- XACT_STATE = 0 means that there is no transaction and a commit or rollback operation would generate an error.
    if (xact_state() = 1 or xact_state() = -1)
          ROLLBACK TRAN
      
    raiserror('%u:: %s', 16, 1, @errSeverity, @errMsg)
      
END CATCH

RETURN 1
GO
CREATE PROCEDURE [dbo].[Employee_Del]
	@Name varchar(20),
	@IsDeleteDescendents bit = 0

--
-- If @IsDeleteDescendents = 0
--		Deletes a single node and
--		puts all child nodes (descendants) under previous parent
-- else
--		Deletes whole subtree starting with the node @Name
--

/*
-- top level
Employee_Del @Name = 'Dave'

-- with parent
Employee_Del @Name = 'Amy'

*/

AS
set nocount on;
set xact_abort on;

BEGIN TRY

	declare @nodeID hierarchyid,
			@newParentNodeID hierarchyid;

	select @nodeID = NodeID, @newParentNodeID = NodeID.GetAncestor(1) from Employee where Name = @Name
	if @nodeID is null begin
		raiserror('Record cannot be found.', 16, 1)
		RETURN -1
	end

	set transaction isolation level SERIALIZABLE;
	BEGIN TRAN

		if @IsDeleteDescendents = 1 begin

			delete Employee where NodeID.IsDescendantOf(@nodeID) = 1

		end else begin

			-- remap all 1st level children
			declare @cr CURSOR,
				@n hierarchyid,
				@np hierarchyid;
			set @cr = cursor read_only forward_only for
				select NodeID
				from Employee
				where NodeID.GetAncestor(1) = @nodeID
			open @cr
			fetch next from @cr into @n
			while @@fetch_status = 0 begin

				select @np = @newParentNodeID.GetDescendant(max(NodeID), NULL)
				from Employee
				where NodeID.GetAncestor(1) = @newParentNodeID;

				update Employee set
					NodeID = NodeID.GetReparentedValue(@n, @np)
				where NodeID.IsDescendantOf(@n) = 1

				fetch next from @cr into @n
			end
			close @cr
			deallocate @cr

			delete Employee where NodeID = @nodeID
		end

	COMMIT TRAN

END TRY
BEGIN CATCH
    declare @errSeverity int,
            @errMsg nvarchar(2048)
    select  @errSeverity = ERROR_SEVERITY(),
            @errMsg = ERROR_MESSAGE()

    -- Test XACT_STATE:
        -- If 1, the transaction is committable.
        -- If -1, the transaction is uncommittable and should be rolled back.
        -- XACT_STATE = 0 means that there is no transaction and a commit or rollback operation would generate an error.
    if (xact_state() = 1 or xact_state() = -1)
          ROLLBACK TRAN
      
    raiserror('%u:: %s', 16, 1, @errSeverity, @errMsg)
      
END CATCH

RETURN 1
GO