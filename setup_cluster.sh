#!/bin/bash
#Author - Sagar Shimpi
#Contributor - xxxxxxxx
#Script will setup and configure ambari-server/ambari-agents and hdp cluster
##########################################################


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
AMBARI_AGENTS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
USER=`grep -w SSH_USER $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
PASSWORD=`grep -w SSH_SERVER_PASSWORD $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
PVT_KEY=`grep -w SSH_SERVER_PRIVATE_KEY $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
IP=`grep -w IP[1-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2|head -n 1`
REPO_SERVER=`grep  -w REPO_SERVER  $LOC/$CLUSTER_PROPERTIES |cut -d'=' -f2`
JAVA_HOME=`grep  -w JAVA  $LOC/$CLUSTER_PROPERTIES |cut -d'=' -f2`
AS=`grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|head -1|cut -d'=' -f2`
AMBARI_SERVER_IP=`awk "/$AS/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
NUM_OF_HOSTS=`cat $LOC/$CLUSTER_PROPERTIES|grep -w HOST[1-50] |wc -l`


#+++++++++++++++++++++++
# Check NUM_OF_NODES and NUM_OF_HOSTS in proeprties file

if [[ $NUM_OF_NODES -eq $NUM_OF_HOSTS ]]
then
        echo "Both values are Equal" > /dev/null
else
        echo -e '\033[41mWARNING!!!!\033[0m \033[36m"NUM_OF_HOSTS" and "NUM_OF_NODES" defined in  $LOC/$CLUSTER_PROPERTIES are not equal. Please remove unwanted entries from file or correct "NUM_OF_NODES" value..\033[0m'
	exit 1;
fi

#+++++++++++++++++++++++


if [ -z $PVT_KEY ]
then
	echo -e "\033[32m`timestamp` \033[32mUsing Plain Password For Cluster Setup\033[0m"
	ssh_cmd="sshpass -p $PASSWORD ssh"
	scp_cmd="sshpass -p $PASSWORD scp"
else
	echo -e "\033[32m`timestamp` \033[32mUsing Private Key For Cluster Setup\033[0m"
	ssh_cmd="ssh -i $PVT_KEY"
	scp_cmd="scp -i $PVT_KEY"
	if [ -e $PVT_KEY ]
	then
		echo "File Exist" &> /dev/null
	else
		echo -e "\033[35mPrivate key is missing.. Please check!!!\033[0m"
		exit 1;
	fi
fi

prepare_hosts_file()
{
        echo -e  "127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4\n::1         localhost localhost.localdomain localhost6 localhost6.localdomain6" > /tmp/hosts
for host in `grep -w HOST[0-9]* $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f2`
do
        host_ip=`awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        echo $host_ip $host.$DOMAIN_NAME >> /tmp/hosts
	if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
	then
		sudo sed -i "/$host/d" /etc/hosts
		sudo bash -c "echo \"$host_ip $host.$DOMAIN_NAME\"  >> /etc/hosts"
	else
		sed -i "/$host/d" /etc/hosts
        	echo $host_ip $host.$DOMAIN_NAME >> /etc/hosts
	fi
done

}


generate_centos_repo()
{
#This will generate internal repo file for Ambari Setup
echo "[Centos7]
name=Centos7 - Updates
baseurl=http://$REPO_SERVER/repo/centos7/
gpgcheck=0
enabled=1
priority=1" > /tmp/centos7.repo

        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		sudo cp /tmp/centos7.repo /etc/yum.repos.d &>/dev/null
		
	else
		cp /tmp/centos7.repo /etc/yum.repos.d &>/dev/null
	fi
}


generate_ambari_repo()
{
#This will generate internal repo file for Ambari Setup
echo "[Updates-ambari-$AMBARIVERSION]
name=ambari-$AMBARIVERSION - Updates
baseurl=http://$REPO_SERVER/repo/ambari/$OS/Updates-ambari-$AMBARIVERSION/
gpgcheck=0
enabled=1
priority=1" > /tmp/ambari-$AMBARIVERSION.repo
}

pre-rep()
{
        for host in `echo $AMBARI_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
		host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		sudo rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/sshpass-1.06-2.el7.x86_64.rpm &> /tmp/sshpass_install.txt
                        wait
        		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mkdir /etc/yum.repos.d/bkp 2> /dev/null
                        wait
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bkp/"  2> /dev/null
                        wait
                        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/ambari-"$AMBARIVERSION".repo $USER@$host_ip:/tmp/ambari-"$AMBARIVERSION".repo &> /dev/null 
                        wait
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/ambari-"$AMBARIVERSION".repo /etc/yum.repos.d/ 2> /dev/null &
                        wait
                        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/centos7.repo $USER@$host_ip:/tmp/centos7.repo &> /dev/null
                        wait
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo cp /tmp/centos7.repo /etc/yum.repos.d/ 2> /dev/null
                        wait
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum clean all 2&>1 /dev/null
                        wait
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo yum -y install mysql-community-release 2&>1 /dev/null
                        wait
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo mv /etc/yum.repos.d/mysql*.repo /tmp" &> /dev/null
                        wait
        else
			rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/sshpass-1.06-2.el7.x86_64.rpm &> /tmp/sshpass_install.txt
                        wait
        		$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip mkdir /etc/yum.repos.d/bkp  &> /dev/null
                        wait
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip  mv /etc/yum.repos.d/*.repo /etc/yum.repos.d/bkp/  &> /dev/null
                        wait
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip rm -rf /etc/yum.repos.d/ambari-*.repo 2> /dev/null  &
                        wait
                        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/ambari-"$AMBARIVERSION".repo $USER@$host_ip:/etc/yum.repos.d/ 2> /dev/null &
                        wait
                        $scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/centos7.repo $USER@$host_ip:/etc/yum.repos.d/ &> /dev/null &
                        wait
	        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip yum clean all 2&>1 /dev/null
                        wait
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip yum -y install mysql-community-release 2&>1 /dev/null
                        wait
                	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "mv /etc/yum.repos.d/mysql*.repo /tmp" &> /dev/null
                        wait
        fi
        done
}


install_java()
{
	echo -e "\033[32m`timestamp` \033[32mInstalling JAVA \033[0m"
	for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        	then
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST sudo rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/jdk-8u151-linux-x64.rpm &> /tmp/java_install.txt
		else
			$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$HOST rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/jdk-8u151-linux-x64.rpm &> /tmp/java_install.txt
		fi
			
	done
}


bootstrap_hosts()
{
        echo -e "\033[32m`timestamp` \033[32mBootstrap Hosts \033[0m"
        for host in `echo $AMBARI_AGENTS`
        do
                HOST=`echo $host`.$DOMAIN_NAME
		host_ip=` awk "/$host/{getline; print}"  $LOC/$CLUSTER_PROPERTIES|cut -d'=' -f 2`
                if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
                then
                	wait
                	$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts $USER@$host_ip:/tmp/hosts.org &> /dev/null &
                	wait
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mv /tmp/hosts.org /etc/hosts 2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo sed -i.bak "s/$USERNAME-$HOST/$HOST/g" /etc/sysconfig/network  2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "sudo echo HOSTNAME=$HOST >> /etc/sysconfig/network"  2> /dev/null &

                	printf "sudo hostname "$HOST" 2>/dev/null\nsudo hostnamectl set-hostname "$HOST"\nsudo hostnamectl set-hostname "$HOST" --static\nsudo systemctl restart systemd-hostnamed\nsudo systemctl stop firewalld.service 2>/dev/null\nsudo systemctl disable firewalld.service 2> /dev/null" > /tmp/commands_centos7
                	cat /tmp/commands_centos7|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip 2>/dev/null			
		else
			wait 
			$scp_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  /tmp/hosts $USER@$host_ip:/tmp/hosts.org &> /dev/null &
			wait 
                        $ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sudo mv /tmp/hosts.org /etc/hosts 2> /dev/null &
                	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip sed -i.bak "s/$USERNAME-$HOST/$HOST/g" /etc/sysconfig/network  2> /dev/null & 
			$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip "echo HOSTNAME=$HOST >> /etc/sysconfig/network"  2> /dev/null &

                	printf "hostname "$HOST" 2>/dev/null\nhostnamectl set-hostname "$HOST"\nhostnamectl set-hostname "$HOST" --static\nsystemctl restart systemd-hostnamed\nsystemctl stop firewalld.service 2>/dev/null 2> /dev/null\nsystemctl disable firewalld.service 2> /dev/null" > /tmp/commands_centos7
                	cat /tmp/commands_centos7|$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$host_ip 2>/dev/null
		fi
        done
}


setup_ambari_server()
{
	echo -e "\033[32m`timestamp` \033[32mInstalling Ambari-Server\033[0m"

#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install ambari-server
#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server setup -s
#        ssh -i $PVT_KEYFILE -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server start
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
	        $ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo yum -y install wget 2&>1 /dev/null
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/jdk-8u151-linux-x64.rpm 2&>1 /dev/null
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo yum -y install ambari-server 2&>1 /dev/null
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo ambari-server setup -s --java-home=$JAVA_HOME &>/tmp/as_setup.txt
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER sudo ambari-server start &> /tmp/as_startup.txt	
        else

        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install wget 2&>1 /dev/null
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER rpm -ivh http://$REPO_SERVER/repo/custom_pkgs/jdk-8u151-linux-x64.rpm 2&>1 /dev/null
        	$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER yum -y install ambari-server 2&>1 /dev/null
        	$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server setup -s --java-home=$JAVA_HOME &>/tmp/as_setup.txt
		$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null"  $USER@$AMBARI_SERVER ambari-server start &> /tmp/as_startup.txt
	fi
}


setup_ambari_agent()
{
	echo -en "\033[32m`timestamp` \033[32mInstalling Ambari-Agent\033[0m"
        for host in `echo $AMBARI_AGENTS`
        do
                AMBARI_AGENT=`echo $host`.$DOMAIN_NAME
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo yum -y install ambari-agent 2&>1 /tmp/aa_install.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo ambari-agent reset $AMBARI_SERVER &> /tmp/aa_reset.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT sudo service ambari-agent start &> /tmp/aa_start.txt
	else
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT yum -y install ambari-agent 2&>1 /tmp/aa_install.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT ambari-agent reset $AMBARI_SERVER &> /tmp/aa_reset.txt
		$ssh_cmd  -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT service ambari-agent start 2&>1 /tmp/aa_start.txt
                #cat /tmp/commands_ambari_agent|$ssh_cmd -o "StrictHostKeyChecking no" -o "CheckHostIP=no" -o "UserKnownHostsFile=/dev/null" $USER@$AMBARI_AGENT & 2&>1 /dev/null
	fi
        done
        wait
}

setup_hdp()
{
        $LOC/generate_json.sh $CLUSTER_PROPERTIES $AMBARI_SERVER_IP
        #printf "\n$(tput setaf 2)Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status!\n\nIt would not take much time :)\n\nHappy Hadooping!\n$(tput sgr 0)"
#	echo -e  "\033[32m`timestamp` Please hit http://$AMBARI_SERVER_IP:8080 in your browser and check installation status"'!'"\033[0m"
        if [ "$CLUSTER_PROPERTIES" = "cluster_cloud.props" ]
        then
		echo -e  "\033[32m`timestamp` \033[32mPlease hit\033[0m \033[44mhttp://$PUBLIC_IP:8080\033[0m \033[32min your browser and check installation status"'!'"\033[0m"
	else
		echo -e  "\033[32m`timestamp` \033[32mPlease hit\033[0m \033[44mhttp://$IP:8080\033[0m \033[32min your browser and check installation status"'!'"\033[0m"
	fi
		
#        mv ~/.ssh/known_hosts.bak ~/.ssh/known_hosts
        #end_time=`date +%s`
        #start_time=`cat /tmp/start_time`
        #runtime=`echo "($end_time-$start_time)/60"|bc -l`
        #printf "\n\n$(tput setaf 2)Script runtime(Including time taken for manual intervention) - $runtime minutes!\n$(tput sgr 0)"
        #TS=`date +%Y-%m-%d,%H:%M:%S`
        #echo "$TS|`whoami`|$runtime" > /tmp/usage_track_"$USER"_"$TS"
}


echo -e  "\033[32m`timestamp` \033[32mGetting Host and IP Details\033[0m"
prepare_hosts_file
echo -e  "\033[32m`timestamp` \033[32mSetting up Base OS Repository\033[0m"
generate_centos_repo
echo -e  "\033[32m`timestamp` \033[32mSetting up Ambari Repository\033[0m"
generate_ambari_repo
echo -e  "\033[32m`timestamp` \033[32mCheck for Pre-requisites\033[0m"
pre-rep
install_java
bootstrap_hosts
setup_ambari_server
setup_ambari_agent
setup_hdp
