FROM luketillman/datastax-enterprise:5.1.0

# Copy schema files into /opt/killrvideo-data
COPY [ "lib/killrvideo-data/schema.cql", "lib/killrvideo-data/search/*.xml", "keyspace.cql", "/opt/killrvideo-data/" ]

# Copy bootstrap script(s) and make executable
COPY [ "bootstrap-external-cluster.sh", "lib/wait-for-it/wait-for-it.sh", "/" ]
RUN chmod +x /bootstrap-external-cluster.sh /wait-for-it.sh

# Set the entrypoint to the bootstrap script
ENTRYPOINT [ "/bootstrap-external-cluster.sh" ]
