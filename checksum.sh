#!/bin/bash
## Compare tables on this MySQL server with a remote MySQL server to determine whether both are in a consistent state
## Example:
## $ ./checksum.sh 192.168.10.101

## Remote DB user
DBUSER=checksum
DBPASS=mypassword
# To create a dedicated checksum user:
# CREATE USER 'checksum'@'192.168.10.%' IDENTIFIED BY 'mypassword';
# GRANT SELECT ON *.* TO 'checksum'@'192.168.10.%';
# CREATE USER 'checksum'@'localhost' IDENTIFIED BY 'mypassword';
# GRANT SELECT ON *.* TO 'checksum'@'locahost';
##

SOURCE=localhost
TARGET=$1
PORT=3306

[ -z $TARGET ] && echo 'Please specify a destination server to compare' && exit 1

SOURCE_CHECKSUM=/tmp/source_checksum
SOURCE_TABLELIST=/tmp/source_tablelist
TARGET_CHECKSUM=/tmp/dest_checksum
TARGET_TABLELIST=/tmp/dest_tablelist

cat /dev/null > $SOURCE_CHECKSUM
cat /dev/null > $SOURCE_TABLELIST
cat /dev/null > $TARGET_CHECKSUM
cat /dev/null > $TARGET_TABLELIST

echo
echo "+====================================================+"
echo "|  This script will compare data on 2 servers and    |"
echo "|  determine whether they are in a consistent state  |"
echo "+====================================================+"
echo
echo "Generating table list on ${SOURCE}..."
mysql -u$DBUSER -p$DBPASS -h $SOURCE -P $PORT -A -Bse 'SELECT CONCAT(table_schema,".", table_name) FROM information_schema.tables WHERE table_schema NOT IN ("mysql","information_schema","performance_schema","sys")' >> $SOURCE_TABLELIST
[ $? -ne 0 ] && echo 'Error while generating table list. Please check if the DB credentials are correct.' && exit 1

for TABLE in $(cat $SOURCE_TABLELIST); do
	mysql -u$DBUSER -p$DBPASS -h $SOURCE -P $PORT -A -Bse "CHECKSUM TABLE $TABLE" >> $SOURCE_CHECKSUM
done

echo "Generating table list on ${TARGET}..."
mysql -u$DBUSER -p$DBPASS -h $TARGET -P $PORT -A -Bse 'SELECT CONCAT(table_schema,".", table_name) FROM information_schema.tables WHERE table_schema NOT IN ("mysql","information_schema","performance_schema","sys")' >> $TARGET_TABLELIST
[ $? -ne 0 ] && echo 'Error while generating table list. Please check if the DB credentials are correct.' && exit 1

for TABLE in $(cat $TARGET_TABLELIST); do
    mysql -u$DBUSER -p$DBPASS -h $TARGET -P $PORT -A -Bse "CHECKSUM TABLE $TABLE" >> $TARGET_CHECKSUM
done

echo
echo "Table list comparison (1/2)"
echo "---------------------------"
echo "Comparing table list on both servers ..."
echo
printf '%-60s %-20s\n' "Source ($SOURCE)" "Destination ($TARGET)"
printf '%-60s %-20s\n' "================" "============================="
diff -y $SOURCE_TABLELIST $TARGET_TABLELIST
echo "----------------"
echo
if [ $? -eq 0 ]; then
        echo -n "Result: "
        echo -e "\e[32mLooks good! No difference found.\e[39m"
        TABLELIST_IS_SYNCED=1
else
        echo -n "Result: "
        echo -e "\e[31mDifference found.\e[39m"
        TABLELIST_IS_SYNCED=0
fi

echo
echo "Checksum comparison (2/2)"
echo "-------------------------"
echo "Comparing tables' checksum for both servers ..."
echo
printf '%-60s %-20s\n' "Source ($SOURCE)" "Destination ($TARGET)"
printf '%-60s %-20s\n' "================" "============================="
diff -y $SOURCE_CHECKSUM $TARGET_CHECKSUM
echo "----------------"
echo
if [ $? -eq 0 ]; then
        echo -n "Result: "
        echo -e "\e[32mLooks good! No difference found.\e[39m"
        TABLES_ARE_SYNCED=1
else
        echo -n "Result: "
        echo -e "\e[31mDifference found.\e[39m"
        TABLES_ARE_SYNCED=0
fi

echo
echo "Summary: "
if [ $TABLELIST_IS_SYNCED -eq 1 ] && [ $TABLES_ARE_SYNCED -eq 1 ]; then
        echo -e "\e[32mData on both servers are consistent.\e[39m"
else
        echo -e "\e[31mData on both servers are NOT consistent. Please sync it first, otherwise data lost might happen!\e[39m"
fi
echo


# Cleaning up temp files
rm -f $SOURCE_CHECKSUM
rm -f $SOURCE_TABLELIST
rm -f $TARGET_CHECKSUM
rm -f $TARGET_TABLELIST
