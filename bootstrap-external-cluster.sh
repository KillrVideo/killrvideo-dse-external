#!/bin/bash

echo '=> KillrVideo DOCKER IP = '$KILLRVIDEO_DOCKER_IP
echo '=> External Cluster IP = '$EXTERNAL_CLUSTER_IP

echo '=> Spoofing Cassandra cluster in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_9042_NAME/external_cluster -XPUT -d value="$EXTERNAL_CLUSTER_IP:9042"

echo '=> Spoofing DSE Search in ETCD'
curl http://$KILLRVIDEO_DOCKER_IP:2379/v2/keys/killrvideo/services/$SERVICE_8983_NAME/external_cluster -XPUT -d value="$EXTERNAL_CLUSTER_IP:8983"

  # See if we've already completed bootstrapping
  if [ ! -f /killrvideo_bootstrapped ]; then
    echo 'Setting up KillrVideo on EXTERNAL cluster'

    # Wait for port 9042 (CQL) to be ready for up to 120 seconds
    echo '=> Waiting for connection to EXTERNAL DSE cluster'
    /wait-for-it.sh -t 120 $EXTERNAL_CLUSTER_IP:9042
    echo '=> EXTERNAL DSE cluster is available'

    # Create the keyspace if necessary
    echo '=> Ensuring keyspace is created'
    cqlsh -f /opt/killrvideo-data/keyspace.cql $EXTERNAL_CLUSTER_IP 9042

    # Create the schema if necessary
    echo '=> Ensuring schema is created'
    cqlsh -f /opt/killrvideo-data/schema.cql -k killrvideo $EXTERNAL_CLUSTER_IP 9042

    # Create DSE Search core if necessary
    echo '=> Ensuring DSE Search is configured'
    search_action='reload'
    
    # Check for config (dsetool will return a message like 'No resource solrconfig.xml found for core XXX' if not created yet)
    cfg="$(dsetool -h $EXTERNAL_CLUSTER_IP get_core_config killrvideo.videos)"
    if [[ $cfg == "No resource"* ]]; then
      search_action='create'
    fi

    # Create or reload core
    if [ "$search_action" = 'create' ]; then
      echo '=> Creating search core'
      dsetool -h $EXTERNAL_CLUSTER_IP create_core killrvideo.videos schema=/opt/killrvideo-data/videos.schema.xml solrconfig=/opt/killrvideo-data/videos.solrconfig.xml
    else
      echo '=> Reloading search core'
      dsetool -h $EXTERNAL_CLUSTER_IP reload_core killrvideo.videos schema=/opt/killrvideo-data/videos.schema.xml solrconfig=/opt/killrvideo-data/videos.solrconfig.xml
    fi

    # Don't bootstrap next time we start
    touch /killrvideo_bootstrapped

    # Now allow DSE to start normally below
    echo 'KillrVideo has been setup, EXTERNAL DSE cluster ready to go'
  fi