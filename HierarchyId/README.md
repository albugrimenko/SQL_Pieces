# Data type "hierarchyid"

In SQL Server 2008 Microsoft introduced a new data type - "hierarchyid". 

The hierarchyid type is implemented as a CLR user defined type, so technically, it is not a SQL-native data type. However, due to its deep integration in SQL server, it can be used even with SQL CLR disabled.

The hierarchyid contains encoded path information for a particular node and can provide access to all parent and child nodes. SQL Server stores it in an extremely compact variable-length format, therefore it requires special functions to work with this data type. By the way, "the average number of bits that are required to represent a node in a tree with n nodes depends on the average number of children of a node, known as the average fanout... In practical terms, one node in a hierarchy of 100,000 nodes with an average fanout of 6 takes about 38 bits, which gets rounded up to 40 bits (5 bytes) of storage."
[ref. "Programming Microsoft SQL Server 2008" by Leonard Lobel, Andrew Brust, Stephen Forte http://www.amazon.com/Programming-Microsoft-Server-2008-PRO-Developer/dp/0735625999/]

### Notes

1. NodeID must be unique. However, hierarchyid functions do NOT guarantee uniqueness - this is developer's responsibility. Therefore we need this constraint to be enforced.
2. If you know upfront that the tree structure is going to be deep, it is better to define NodeID as a primary clustered key, because it will give you the best performance for depth first searches. Otherwise, a separate index is required.
3. For the wide trees an additional index could be helpful - it optimizes breadth first searches and defined in a very similar fashion:

``
CREATE UNIQUE INDEX IX_EmployeeBreadth_Uniq
on Employee(NodeLevel, NodeID)
GO
``

The basic insert / update / delete operations should take care of NodeID value. There are several special functions available to work with hierarchyid. Most commonly used are:

* hierarchyid::GetRoot() - points to the root NodeID
* GetAncestor - gets parent (ancestor(s)) of the specified node
* GetDescendant - gets child nodes

In the book I mentioned above, I found an interesting function that generates full path for any given node. This function is quite useful, especially in testing and debugging, but I would not recommend to use it in a production mode for large trees. Function code is listed in the **Hierarchyid_fn.sql**.

Important thing to remember when working with hierarchyid is to take care of NodeID values in delete operations. SQL allows you to delete any node from the tree which may produce orphan nodes. Therefore, every time when we need to delete a node we have to do something with its child nodes. Possible solutions could be delete all its child nodes as well or re-link all child nodes to the root. Sometimes it is better to re-link all its child nodes to the node above. Delete stored procedures are listed in the **Hierarchyid_sp.sql**.

The code here is just a sample, in the real life, I needed to implement some sort of a family tree. In other words, I need to keep track of two parents of each node. I did not want to create a mess in my main table where I store information about objects, therefore I keep my hierarchyid fields in a separate table with a set of required stored procedures to work with it. It also gives me some flexibility - I can easily turn this feature on or off when needed.
