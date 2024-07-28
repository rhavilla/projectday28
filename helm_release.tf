resource "helm_release" "wordpress" {
  depends_on = [aws_db_instance.rds]

  name       = "wordpress"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "wordpress"
  namespace  = "default"
  version    = "23.0.9"

values = [templatefile("wordpress_values.yaml", {
  rds_endpoint =split(":", aws_db_instance.rds.endpoint)[0],
  rds_username =aws_db_instance.rds.username,
  rds_password =aws_db_instance.rds.password,
  rds_database =aws_db_instance.rds.db_name 

})]
}

resource "helm_release" "metricserver" {
  depends_on = [aws_db_instance.rds]

  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  namespace  = "kube-system"

}
resource "null_resource" "download_iam_policy" {
  provisioner "local-exec" {
    command = "curl -O https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json"
  }
}

resource "aws_iam_policy" "aws_load_balancer_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  policy      = file("iam_policy.json")
  depends_on  = [null_resource.download_iam_policy]
}

data "aws_caller_identity" "current" {}

data "aws_eks_cluster" "cluster" {
  name = "rhavila-eks"
}

resource "aws_iam_role" "eks_load_balancer_controller_role" {
  name = "AmazonEKSLoadBalancerControllerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          "StringEquals" = {
            "${replace(aws_eks_cluster.eks.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_load_balancer_controller_policy_attachment" {
  role       = aws_iam_role.eks_load_balancer_controller_role.name
  policy_arn = aws_iam_policy.aws_load_balancer_controller_policy.arn
}


resource "kubernetes_service_account" "aws_load_balancer_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.eks_load_balancer_controller_role.arn
    }
  }
}

resource "helm_release" "aws_load_balancer_controller"{
  depends_on = [kubernetes_service_account.aws_load_balancer_controller, null_resource.download_and_apply_crds]

  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.2.3"  # Specify the version of the Helm chart
  timeout    = 800      # Increase timeout to 10 minutes

  set {
    name  = "clusterName"
    value = "rhavila-eks"
  }

  set {
    name  = "serviceAccount.create"
    value = true
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = "vpc-0bff29bccdee44d22"
  }
}


resource "null_resource" "download_and_apply_crds" {
  provisioner "local-exec" {
    command = <<EOT
      wget https://raw.githubusercontent.com/aws/eks-charts/master/stable/aws-load-balancer-controller/crds/crds.yaml
      kubectl apply -f crds.yaml
    EOT
  }
}
