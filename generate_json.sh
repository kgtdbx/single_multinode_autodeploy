#!/bin/bash
########
# Author: Sagar Shimpi
# Description: This script does the Magic of automating HDP install using Ambari Blueprints


#Cleanup script
mv $LOC/cluster_config.json /tmp &>/dev/null
mv $LOC/hostmap.json /tmp &>/dev/null
mv $LOC/repo* /tmp &>/dev/null
mv $LOC/list /tmp &>/dev/null

#Globals
LOC=`pwd`
PROPS=$1
#Source props
source $LOC/$PROPS 2>/dev/null
STACK_VERSION=`echo $CLUSTER_VERSION|cut -c1-3`
AMBARI_HOST=$2
NUMBER_OF_HOSTS=`grep HOST $LOC/$PROPS|grep -v SERVICES|wc -l`
LAST_HOST=`grep HOST $LOC/$PROPS|grep -v SERVICES|head -n $NUMBER_OF_HOSTS|tail -1|cut -d'=' -f2`
grep HOST $LOC/$PROPS|grep -v SERVICES|grep -v $LAST_HOST|cut -d'=' -f2 > $LOC/list
OS_VERSION=`echo $OS|rev|cut -c1|rev`

echo $HOST
#Generate hostmap function#

hostmap()
{
#Start of function

echo "{
  \"blueprint\" : \"$CLUSTERNAME\",
  \"default_password\" : \"$DEFAULT_PASSWORD\",
  \"host_groups\" :["

for HOST in `cat list`
do
   echo "{
      \"name\" : \"$HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$HOST.$DOMAIN_NAME\"
        }
      ]
    },"
done

echo "{
      \"name\" : \"$LAST_HOST\",
      \"hosts\" : [
        {
          \"fqdn\" : \"$LAST_HOST.$DOMAIN_NAME\"
        }
      ]
    }
  ]
}"

#End of function
}

clustermap()
{
#Start of function
LAST_HST_NAME=`grep 'HOST[0-9]*' $LOC/$PROPS|grep -v SERVICES|tail -1|cut -d'=' -f1`

echo "{
  \"configurations\" : [ ],
  \"host_groups\" : ["

for HOST in `grep -w 'HOST[0-9]*' $LOC/$PROPS|tr '\n' ' '`
do
   HST_NAME_VAR=`echo $HOST|cut -d'=' -f1`
   echo "{
      \"name\" : \"`grep $HST_NAME_VAR $PROPS |head -1|cut -d'=' -f2|cut -d'.' -f1`\",
      \"components\" : ["
		LAST_SVC=`grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|rev|cut -d' ' -f1|rev|cut -d'"' -f1`
		for SVC in `grep $HST_NAME_VAR"_SERVICES" $LOC/$PROPS|cut -d'=' -f2|tr ',' ' '|cut -d'"' -f2|cut -d'"' -f1`
		do
        		echo "{
			\"name\" : \"$SVC\""
			if [ "$SVC" == "$LAST_SVC" ]
			then
				echo "}
				],
      			        \"cardinality\" : "1""
				if [ "$HST_NAME_VAR" == "$LAST_HST_NAME" ]
				then
    	               		    	echo "}"
				else
					echo "},"
				fi
			else
       	 				echo "},"
			fi
		done
done

echo "  ],
  \"Blueprints\" : {
    \"blueprint_name\" : \"$CLUSTERNAME\",
    \"stack_name\" : \"HDP\",
    \"stack_version\" : \"$STACK_VERSION\"
  }
}"


#End of function
}

#Setting up Repositories

repobuilder()
{
#Start of function
BASE_URL="http://$REPO_SERVER/repo/hdp/$OS/HDP-$CLUSTER_VERSION/"


echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL\",
   \"verify_base_url\" : true
}
}" > $LOC/repo.json

BASE_URL_UTILS="http://$REPO_SERVER/repo/hdp/$OS/HDP-UTILS-$UTILS_VERSION/"

export BASE_URL_UTILS;

echo "{
\"Repositories\" : {
   \"base_url\" : \"$BASE_URL_UTILS\",
   \"verify_base_url\" : true
}
}" > $LOC/repo-utils.json

#End of function
}

#Function to print timestamp
timestamp()
{
echo -e  "\033[36m`date +%Y-%m-%d-%H:%M:%S`\033[0m"
}

installhdp()
{
#Install hdp using Ambari Blueprints
echo -e "\033[32m`timestamp` \033[32mInstalling HDP Using Blueprints\033[0m"

HDP_UTILS_VERSION=`echo $BASE_URL_UTILS| awk -F'/' '{print $7}'`

curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/blueprints/$CLUSTERNAME -d @"$LOC"/cluster_config.json 2&>1 /tmp/curl_cc_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/HDP-$STACK_VERSION -d @$LOC/repo.json 2&>1 /tmp/repo_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X PUT -u admin:admin http://$AMBARI_HOST:8080/api/v1/stacks/HDP/versions/$STACK_VERSION/operating_systems/redhat"$OS_VERSION"/repositories/$HDP_UTILS_VERSION -d @$LOC/repo-utils.json 2&>1 /tmp/repo_utils_json.txt
sleep 1
curl -H "X-Requested-By: ambari" -X POST -u admin:admin http://$AMBARI_HOST:8080/api/v1/clusters/$CLUSTERNAME -d @$LOC/hostmap.json &> /tmp/hostmap_json.txt

}

#################
# Main function #
################

#Generate hostmap
echo -e "\033[032m`timestamp` \033[32mGenerating hostmap json..\033[0m"
hostmap > $LOC/hostmap.json
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/hostmap.json\033[0m"

#Generate cluster config json
echo -e "\033[032m`timestamp` \033[32mGenerating cluster configuration json\033[0m"
clustermap > $LOC/cluster_config.json
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/cluster_config.json\033[0m"

#Create internal repo json 
echo -e "\033[032m`timestamp` \033[32mGenerating internal repositories json..\033[0m"
repobuilder 
echo -e "\033[032m`timestamp` \033[32mSaved $LOC/repo.json & $LOC/repo-utils.json\033[0m"

#Start hdp installation
installhdp
