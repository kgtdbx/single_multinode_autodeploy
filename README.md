# cloud_hdp_auto_deploy
HDP automated install using blueprint

#setup_cluster.sh - This is parent script. Running this script along with arguments set up your HDP cluster in automated way. Before you run this script make sure you have modified "cluster_props" file according to your environment.
	
#cluster.props - This script is used when you are installing hadoop ON_PREMISES or Bare-Metal servers. This file defines all variable used to install/setup you Ambari/HDP. Please do make sure you have set correct values in this file.

#cluster_cloud.props - For Cloud installation you need to provide this file as params to "setup_cluster.sh" script. This file defines all variable used to install/setupyou Ambari/HDP. Please do make sure you have set correct values in this file.

#generate_json.sh - This will generate blueprint and trigger the HDP installation.

#post_script.sh - Post script will execute add-on task required to be setup after HDP installation.




#How to run the script

./setup_cluster.sh <path_to_cluster_props_file>
