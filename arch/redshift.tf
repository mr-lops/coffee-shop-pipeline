# Criando um cluster Amazon Redshift
resource "aws_redshift_cluster" "redshift-cluster" {
  cluster_identifier        = "redshift-cluster"                                      # Identificador único para o cluster Redshift
  database_name             = "ingest_data_db"                                        # Nome do banco de dados dentro do cluster
  master_username           = var.master_username                                     # Usuário mestre para autenticação no banco de dados
  master_password           = var.master_password                                     # Senha do usuário mestre
  node_type                 = "dc2.large"                                             # Tipo de nó para o cluster
  cluster_type              = "single_node"                                           # Tipo de cluster (neste caso, um único nó)
  number_of_nodes           = 1                                                       # Número de nós no cluster
  publicly_accessible       = true                                                    # Cluster é acessível publicamente (RECOMENDA-SE deixar como false e acessar via VPN ou IP específico)
  vpc_security_group_ids    = [aws_vpc.ingest-data-vpc.id]                            # IDs dos grupos de segurança associados ao cluster
  skip_final_snapshot       = true                                                    # Ignorar a criação de um snapshot final quando o cluster for excluído
  cluster_subnet_group_name = aws_redshift_subnet_group.ingest-data-subnet-group.name # Nome do grupo de subnets associado ao cluster
}





