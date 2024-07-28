resource "aws_eks_cluster" "eks" {
  name     = "rhavila-eks"
  role_arn = aws_iam_role.master.arn

  kubernetes_network_config {
    ip_family = "ipv4"

  }

  vpc_config {
    endpoint_private_access = false
    endpoint_public_access  = true
    subnet_ids              = [aws_subnet.public-1.id, aws_subnet.public-2.id]

  }

  access_config {
    authentication_mode                         = "API"
    bootstrap_cluster_creator_admin_permissions = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.AmazonEKSClusterPolicy,
    aws_iam_role_policy_attachment.AmazonEKSServicePolicy,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    aws_iam_role_policy_attachment.AmazonEKSVPCResourceController,
    #aws_subnet.pub_sub1,
    #aws_subnet.pub_sub2,
  ]

}

// Criar par de chaves no EC2 usando a chave pública
resource "aws_key_pair" "existing_key" {
  key_name   = "tf-key.pem"
  public_key = file("/home/rha/.ssh/id_rsa.pub") // Supondo que o arquivo .pub contendo a chave pública está no mesmo local
}

resource "aws_eks_addon" "vpc_cni" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "vpc-cni"
  addon_version     = "v1.16.0-eksbuild.1" # Verifique e use a versão mais recente disponível
  resolve_conflicts_on_create = "OVERWRITE"
}
resource "aws_eks_addon" "kube_proxy" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "kube-proxy"
  addon_version     = "v1.29.0-eksbuild.1" # Verifique e use a versão mais recente disponível
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "core_dns" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "coredns"
  addon_version     = "v1.11.1-eksbuild.9" # Verifique e use a versão mais recente disponível
  resolve_conflicts_on_create = "OVERWRITE"
}

resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name      = aws_eks_cluster.eks.name
  addon_name        = "aws-ebs-csi-driver"
  addon_version     = "v1.32.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
}
