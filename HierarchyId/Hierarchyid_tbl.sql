CREATE TABLE [dbo].[Employee](
	ID int not null identity(0,1) constraint PK_Employee primary key clustered,
	NodeID hierarchyid constraint UQ_Employee_NodeID unique,
	NodeLevel as NodeID.GetLevel(),	-- smallint
	Name varchar(20) not null,
	Title varchar(20) null
)
GO
CREATE UNIQUE INDEX IX_EmployeeBreadth_Uniq
on Employee(NodeLevel, NodeID)
GO

-- Root record
insert into Employee (NodeID, Name, Title)
values (hierarchyid::GetRoot(), 'Root', null)
GO
--select * from Employee