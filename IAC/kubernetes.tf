provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  token                  = data.aws_eks_cluster_auth.cluster.token
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
}

resource "kubernetes_config_map" "mongo_config" {
  metadata {
    name      = "mongo-config"
    namespace = "project"

    labels = {
      app = "mongo"
    }
  }

  data = {
    DB_PASSWORD = "password123"

    DB_USER = "dbuser"
  }
}

resource "kubernetes_service" "mongod" {
  metadata {
    name      = "mongod"
    namespace = "project"
  }

  spec {
    type          = "ExternalName"
    external_name = module.ec2_instance.0.public_dns
  }
}

resource "kubernetes_namespace" "project" {
  metadata {
    name = "project"

    labels = {
      "app.kubernetes.io/instance" = "ingress-nginx"

      "app.kubernetes.io/name" = "ingress-nginx"
    }
  }
}

resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = "project"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "frontend"
      }
    }

    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }

      spec {
        container {
          name  = "frontend"
          image = "jtb75/project:latest"

          port {
            container_port = 80
          }

          env_from {
            config_map_ref {
              name = "mongo-config"
            }
          }

          image_pull_policy = "Always"
        }
      }
    }
  }
}

resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = "project"

    labels = {
      app = "frontend"
    }
  }

  spec {
    port {
      port = 80
    }

    selector = {
      app = "frontend"
    }

    type = "LoadBalancer"
  }
}

resource "kubernetes_cluster_role_binding" "permissive_binding" {
  metadata {
    name = "permissive-binding"
  }

  subject {
    kind = "User"
    name = "admin"
  }

  subject {
    kind = "User"
    name = "kubelet"
  }

  subject {
    kind = "Group"
    name = "system:serviceaccounts"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
}
