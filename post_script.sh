#!/bin/bash

#+++++++++++++++++++++++
# Usage Function
if [ $# -ne 1 ]
then
        printf "Usage $0 /path-to/cluster.props\nExample: $0 /opt/single_multinode_autodeploy/<cluster props File> \n"
        exit
fi
#+++++++++++++++++++++++


#Function to print timestamp
timestamp()
{
echo -e  "\033[36m`date +%Y-%m-%d-%H:%M:%S`\033[0m"
}


#Globals VARS

LOC=`pwd`
CLUSTER_PROPERTIES=$1
sed -i  's/[ \t]*$//'  $LOC/$CLUSTER_PROPERTIES
source $LOC/$CLUSTER_PROPERTIES 2>/dev/null
AMBARI_SERVER=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`.$DOMAIN_NAME


/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME hive-site "hive.auto.convert.join" "false"

/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME hive-site "hive.optimize.index.filter"  "false"

/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME hive-site  "datanucleus.autoCreateSchema"  "false"

/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME hive-site "hive.server2.transport.mode"  "binary"

/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME hive-site "hive.execution.engine" "mapreduce"

 /var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME spark2-defaults "spark.sql.hive.convertMetastoreParquet" "false"

/var/lib/ambari-server/resources/scripts/configs.sh -u admin -p admin -port 8080 set $AMBARI_SERVER $CLUSTERNAME mapred-site "mapreduce.job.queuename" "MaxiqQueue"

