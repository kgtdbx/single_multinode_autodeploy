#!/bin/bash

LOC=`pwd`
CLUSTER_PROPERTIES=$1
source $LOC/$CLUSTER_PROPERTIES 2&>1 /dev/null
#components="NAMENODE"
components="NAMENODE HIVE_SERVER HBASE_MASTER RESOURCEMANAGER ZOOKEEPER_SERVER OOZIE_SERVER"

serv_fun(){
                echo "Service URL for $service is as below:"

                service_name=`cat $LOC/$CLUSTER_PROPERTIES |grep -w HOST[1-9]*_SERVICES |grep -i $service |cut -d"_" -f1|tr '\n' ' '`
                #echo $service_name
                service_host=`grep $service_name $LOC/$CLUSTER_PROPERTIES |head -n 1 |awk -F "=" '{print $2}'`
                #echo $service_host

}

for service in $components
do
        if [ $service == NAMENODE ]
        then
		serv_fun	
                service_url=$service_host.$DOMAIN_NAME:8020
                echo $service_url
        elif [ $service == "ZOOKEEPER_SERVER" ]
        then
                                        rm -fr /tmp/test_var
                                        rm -fr /tmp/test_f_var
                                service_name=`cat $LOC/$CLUSTER_PROPERTIES |grep -w HOST[1-9]*_SERVICES |grep -i $service |cut -d"_" -f1|tr '\n' ' '`
                                for zk_server in $service_name
                                do
                                        service_host=`grep $zk_server $LOC/$CLUSTER_PROPERTIES |head -n 1 |awk -F "=" '{print $2}'`
                                        echo $service_host|tr '\n' ' ' >> /tmp/test_var
                                        cat /tmp/test_var |sed s'/.$//' | sed 's/ /,/g'> /tmp/test_f_var
                                done
					ZK_URL=`cat /tmp/test_f_var`
					echo  "Service URL for $service is as below:"
					echo $ZK_URL
        elif [ $service == "RESOURCEMANAGER" ]
        then
                #echo "Service URL for $service is as below:"
		serv_fun	
		echo $service_host.$DOMAIN_NAME:8050
		

	
        else
		serv_fun
                service_url=$service_host.$DOMAIN_NAME
                echo $service_url
        fi

done
