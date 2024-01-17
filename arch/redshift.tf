# Creating an Amazon Redshift cluster
resource "aws_redshift_cluster" "redshift-cluster" {
  cluster_identifier        = "redshift-cluster"                                      # Unique identifier for the Redshift cluster
  database_name             = "ingest_data_db"                                        # Name of the database within the cluster
  master_username           = var.master_username                                     # Master user for database authentication
  master_password           = var.master_password                                     # Master user's password
  node_type                 = "dc2.large"                                             # Node type for the cluster
  cluster_type              = "single_node"                                           # Cluster type (in this case, a single node)
  number_of_nodes           = 1                                                       # Number of nodes in the cluster
  publicly_accessible       = true                                                    # Cluster is publicly accessible (RECOMMENDED to leave as false and access via VPN or specific IP)
  vpc_security_group_ids    = [aws_vpc.ingest-data-vpc.id]                            # IDs of the security groups associated with the cluster
  skip_final_snapshot       = true                                                    # Skip the creation of a final snapshot when the cluster is deleted
  cluster_subnet_group_name = aws_redshift_subnet_group.ingest-data-subnet-group.name # Name of the subnet group associated with the cluster
}
