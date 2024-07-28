resource "kubernetes_config_map" "filebeat_config" {
  metadata {
    name      = "filebeat-config"
    namespace = "default"
  }

  data = {
    "filebeat.yml" = <<EOF
filebeat.inputs:
- type: log
  paths:
    - /var/log/apache-logs-dir/access_log
    - /var/log/apache-logs-dir/error_log
  fields:
    cluster: "rha-cluster"
    source: "apache2"
    environment: "production"
  fields_under_root: true
processors:
- add_cloud_metadata: {}
- add_host_metadata: {}
output.logstash:
  hosts: ["elk.htsuyoshiy.online:5044"]
EOF
  }
}