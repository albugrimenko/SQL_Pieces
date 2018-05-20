---------------- Find a string in all objects ---------------
select distinct o.type, o.name
from sysobjects o
	join syscomments c on o.id = c.id
where c.text like '%text to search%'

-------------------------------------------------------------