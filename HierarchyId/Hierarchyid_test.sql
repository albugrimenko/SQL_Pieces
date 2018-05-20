-- with parent
exec Employee_Put @Name = 'John', @Title = 'Marketing Specialist', @ParentName = 'Amy'
exec Employee_Put @Name = 'Kevin', @Title = 'Marketing Specialist', @ParentName = 'Amy'
exec Employee_Put @Name = 'Mary', @Title = 'Marketing Specialist', @ParentName = 'Amy'
exec Employee_Put @Name = 'A', @Title = 'Marketing Intern', @ParentName = 'Mary'
exec Employee_Put @Name = 'B', @Title = 'Marketing Intern', @ParentName = 'Mary'

exec Employee_Put @Name = 'Intern 1', @Title = 'Marketing Intern', @ParentName = 'John'
exec Employee_Put @Name = 'Aby', @Title = 'Sales Director', @ParentName = 'Dave'
exec Employee_Put @Name = 'Aby', @Title = 'Sales Director', @ParentName = 'Amy'
exec Employee_Put @Name = 'Sam', @Title = 'Sales Rep', @ParentName = 'Aby'

-----------
exec Employee_Put @Name = 'Phil', @Title = 'I Manager', @ParentName = 'Dave'
exec Employee_Put @Name = 'Phil 1', @Title = 'I employee', @ParentName = 'Phil'
exec Employee_Put @Name = 'Phil 2', @Title = 'I employee', @ParentName = 'Phil'
exec Employee_Put @Name = 'Phil 3', @Title = 'I employee', @ParentName = 'Phil'
exec Employee_Put @Name = 'Phil 4', @Title = 'I employee', @ParentName = 'Phil'
exec Employee_Put @Name = 'Phil 2', @Title = 'Dave employee', @ParentName = 'Dave'
exec Employee_Put @Name = 'Phil Subd', @ParentName = 'Phil 3', @Title = 'Phil 3 Intern'

exec Employee_Del @Name = 'Phil'	--, @IsDeleteDescendents = 1