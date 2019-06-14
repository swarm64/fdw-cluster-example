# Script to set up a local FDW-based cluster

Set up a FDW-based cluster for experimentation. For simplicity, the data node(s) and the coordinator node(s) are all running on the same machine (localhost).

The script creates a new database called `cluster` that isolates the example from the rest of your PostgreSQL instance. After running the script in your PostgreSQL client, you can use the `lineitem` and `orders` tables as if they were on a dedicated coordinator node.