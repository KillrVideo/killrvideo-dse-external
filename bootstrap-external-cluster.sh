#!/bin/bash

echo '=> KillrVideo DOCKER IP = '$KILLRVIDEO_DOCKER_IP
echo '=> External Cluster IP = '$EXTERNAL_CLUSTER_IP
echo '=> Username = '$USERNAME
echo '=> Password = '$PASSWORD

# This is dirty, I'm sorry.  We have a race condition between the keys generated via the dse container
# and the dse-external container.  In the dse-external case we need to delete the "local" server IP
# reference and point to our remote cluster.  I need to sleep here to ensure the "local" is created.
# I would look it up, but the key name is dynamically generated from another service and etcd does not have
# a wildcard search function that I know of nor do I have a reference to the actual name so I am relegated
# to just ham-fisting this and wiping the whole dir responsible for each key I care about.
sleep 5

echo '=> Deleting Cassandra keys in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_9042_NAME?recursive=true -XDELETE
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_8983_NAME?recursive=true -XDELETE
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_8182_NAME?recursive=true -XDELETE

echo '=> Spoofing Cassandra cluster in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_9042_NAME/external_cluster -XPUT -d value="$EXTERNAL_CLUSTER_IP:9042"

echo '=> Spoofing DSE Search in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_8983_NAME/external_cluster -XPUT -d value="$EXTERNAL_CLUSTER_IP:8983"

echo '=> Spoofing DSE Graph in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_8182_NAME/external_cluster -XPUT -d value="$EXTERNAL_CLUSTER_IP:8182"

  # See if we've already completed bootstrapping
  if [ ! -f /killrvideo_bootstrapped ]; then
    echo 'Setting up KillrVideo on EXTERNAL cluster'

    # Wait for port 9042 (CQL) to be ready for up to 120 seconds
    echo '=> Waiting for connection to EXTERNAL DSE cluster'
    /wait-for-it.sh -t 120 $EXTERNAL_CLUSTER_IP:9042
    echo '=> EXTERNAL DSE cluster is available'

    # Create the keyspace if necessary
    echo '=> Ensuring keyspace is created'
    cqlsh -f /opt/killrvideo-data/keyspace.cql $EXTERNAL_CLUSTER_IP 9042 -u $USERNAME -p $PASSWORD

    # Create the schema if necessary
    echo '=> Ensuring schema is created'
    cqlsh -f /opt/killrvideo-data/schema.cql -k killrvideo $EXTERNAL_CLUSTER_IP 9042 -u $USERNAME -p $PASSWORD

    # Create DSE Search core if necessary
    echo '=> Ensuring DSE Search is configured'
    search_action='reload'

    # Check for config (dsetool will return a message like 'No resource solrconfig.xml found for core XXX' if not created yet)
    cfg="$(dsetool -h $EXTERNAL_CLUSTER_IP get_core_config killrvideo.videos -l $USERNAME -p $PASSWORD)"
    if [[ $cfg == "No resource"* ]]; then
      search_action='create'
    fi

    # Create or reload core
    if [ "$search_action" = 'create' ]; then
      echo '=> Creating search core'
      dsetool -h $EXTERNAL_CLUSTER_IP create_core killrvideo.videos schema=/opt/killrvideo-data/videos.schema.xml solrconfig=/opt/killrvideo-data/videos.solrconfig.xml -l $USERNAME -p $PASSWORD
    else
      echo '=> Reloading search core'
      dsetool -h $EXTERNAL_CLUSTER_IP reload_core killrvideo.videos schema=/opt/killrvideo-data/videos.schema.xml solrconfig=/opt/killrvideo-data/videos.solrconfig.xml -l $USERNAME -p $PASSWORD
    fi

    # Wait for port 8182 (Gremlin) to be ready for up to 120 seconds
    echo '=> Waiting for DSE Graph to become available'
    /wait-for-it.sh -t 120 $EXTERNAL_CLUSTER_IP:8182
    echo '=> DSE Graph is available'

    # Update the gremlin-console remote.yaml file to set the 
    # remote hosts, username, and password
    echo '=> Setting up remote.yaml for gremlin-console'
    sed -i "s/.*hosts:.*/hosts: [$EXTERNAL_CLUSTER_IP]/;s/.*username:.*/username: $USERNAME/;s/.*password:.*/password: $PASSWORD/;" /opt/dse/resources/graph/gremlin-console/conf/remote.yaml 

    # Create the graph if necessary
    echo '=> Ensuring graph is created'
    dse gremlin-console -e /opt/killrvideo-data/killrvideo_video_recommendations_schema.groovy

    # Don't bootstrap next time we start
    touch /killrvideo_bootstrapped

    # Now allow DSE to start normally below
    echo 'KillrVideo has been setup, EXTERNAL DSE cluster ready to go'
  fi
