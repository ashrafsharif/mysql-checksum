# MySQL Checksum Script

This script will compare checksum values for all tables on the local server (where this script is executed) with a remote server.

This script utilizes the `CHECKSUM TABLE` statement and compare it with the output from another server using `diff` command. This script is useful if you want to verify all nodes are indeed in synced especially during a switchover/failover before resuming the application back in production.

# Usage

The script should be running on any node in a replication chain. In the following example architecture, you can run the script on `DB3` to compare it with `DB1` and `DB2`:

```
1 master, 2 slaves of MariaDB Replication with GTID enabled

+-------+                             +-------+
|  DB1  |------async replication----> |  DB2  |
+-------+                             +-------+
     \                                      
      \                               +-------+
       +-------async replication----> |  DB3  |
                                      +-------+
```

Where:

* `DB1`: 192.168.10.101
* `DB2`: 192.168.10.102
* `DB3`: 192.168.10.103

## Create database user

For performance matters, this script requires two database users with SELECT privileges (one for localhost via socket and one for TCP/IP connection). Therefore, create two user-host as below:

```
MariaDB> CREATE USER 'checksum'@'localhost' IDENTIFIED BY 'mypassword';
MariaDB> GRANT SELECT ON *.* TO 'checksum'@'localhost';
MariaDB> CREATE USER 'checksum'@'192.168.10.%' IDENTIFIED BY 'mypassword';
MariaDB> GRANT SELECT ON *.* TO 'checksum'@'192.168.10.%';
```

** The above will create two database users with same username but different hosts (localhost = socket while 192.168.10.% = pattern matching for all IP under 192.168.10.0/24 network).

## Running the script

Before running the script, make sure the application is not sending any writes to the cluster (otherwise the result will always be inconsistent), or the replication slave must be stopped between two nodes that you want to compare. In this example, we are going to stop the replication slave on `DB3` momentarily:

```
MariaDB> STOP SLAVE;
```

Invoke the command by specifying one of the remote server that you want to compare. On `DB3`, run the following command to compare with `DB1`:

```
 ./checksum.sh 192.168.10.101
```

Example output:

```
$ ./checksum.sh 192.168.10.101

+====================================================+
|  This script will compare data on 2 servers and    |
|  determine whether they are in a consistent state  |
+====================================================+

Generating table list on localhost...
Generating table list on 192.168.10.101...

Table list comparison
---------------------

Source table list (localhost):
sbtest.sbtest1
sbtest.sbtest2
sbtest.sbtest3
sbtest.sbtest4
sbtest.sbtest5

Target table list (192.168.10.101):
sbtest.sbtest1
sbtest.sbtest2
sbtest.sbtest3
sbtest.sbtest4
sbtest.sbtest5

Comparing table list on both servers ...
Result: Looks good! No difference found.

Checksum comparison
-------------------

Source checksum (localhost):
sbtest.sbtest1	4021674442
sbtest.sbtest2	3375019626
sbtest.sbtest3	1332937866
sbtest.sbtest4	309612080
sbtest.sbtest5	78379596

Target checksum (192.168.10.101):
sbtest.sbtest1	4021674442
sbtest.sbtest2	3375019626
sbtest.sbtest3	1332937866
sbtest.sbtest4	309612080
sbtest.sbtest5	78379596

Comparing tables' checksum for both servers ...
Result: Looks good! No difference found.

Summary:
Data on both servers are consistent.
```

Once you get the result, resume the replication again or fix the node if data is not consistent:

```
MariaDB> START SLAVE;
```
