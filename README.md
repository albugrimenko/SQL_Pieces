# SQL_Pieces
SQL Snippets, useful utility scripts and functions and samples.

## Hierarchy Id

Occasionally, I need to store hierarchical data in a database. Most common task I've been dealing with is forum posts, where users can make a new post or respond to an existing one or somebody else's response. Another good example would be a necessity to store a tree structure. Essentially, it requires support of unlimited hierarchy of objects (rows).

Of course, it is easy to implement in a relational database by adding a couple extra fields:

* ParentID - a link to the "parent" node. It points to another record within the same table.
* RootID - link to the beginning of the "conversation" or to the root node.

RootID technically is not required, but very often is useful. Especially if you need to answer questions like "show the whole sub tree" or "show all messages in a conversation". Having RootID in a table make it very easy. More complex questions require more tricks. Questions like "show all leaves in a sub tree" may require recursion, which is usually expensive to implement in SQL.

One of the flexible and beautiful implementations I know, called **"Nested set model"**. It requires some extra work, 2 additional fields for each record, but let you answer all sorts of questions about your tree structure in a simple select statements. The catch is it works great for reads, but requires extra updates for each insert/update operation. Here are the details:
https://en.wikipedia.org/wiki/Nested_set_model

In SQL Server 2008 Microsoft introduced a new data type - "hierarchyid". Here is a [sample code to play with this data type](https://github.com/albugrimenko/SQL/tree/master/HierarchyId).

## System Utils

Contains stored procedures I'm using for SQL health and performance monitoring. I found it helpful to have them on each SQL server, usually in a dedicated "util" database. This database may not have user tables at all and generally used as a storage for these utility stored procedures and scripts.

* stat_IndexAnalysis.sql - gets basic statistics about indexes, including data on missing and not used indexes.
* stat_OpenConnections.sql - returns list of open connections to all databses on the server.
* stat_MostExpensiveQueries.sql - returns last N most expensive queries
* util_BackupFull_Daily.sql - Auto adds day name to the end of file name to keep daily backups for the last week.
* util_DefragReindexAuto.sql - Shows table(s) indices fragmentation and defrag or rebuild them if neccessary.
* sp_who_active.sql - Shows all active connections to the server
* sp_WhoIsActive.sql - Adam Machanic's famous "Who Is Active?"

## Useful Functions

A set of usefult functions for different purposes... For example, a set of functions of conversion date types to int and back. 

## Data Sync

DataSync folder contains scripts for data synchronization and change tracking.

### LookupTablesSync

A simple way to easy syncronize lookup tables content. It is just an example, which assumes that the only lookup table is Lookup01 with a simple ID, Name structure.

This solution is useful for relatively small lookup tables that are fairly well normalized. Normalization makes it difficult to keep data in sync in multiple environments, but this script allows to do it fairly easy. 

Keeping all data in scripts also allows to keep it in the source safe database and therefore be able to compare different versions.

