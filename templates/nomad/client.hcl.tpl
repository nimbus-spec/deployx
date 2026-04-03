# Nomad Client Configuration
# Hostname: {{ HOSTNAME }}

name = "{{ HOSTNAME }}"
datacenter = "dc1"
region = "global"

data_dir = "/opt/nomad/data"
log_level = "INFO"

bind_addr = "0.0.0.0"

addresses {
  http = "0.0.0.0"
  rpc = "0.0.0.0"
  serf = "0.0.0.0"
}

ports {
  http = 4646
  rpc = 4647
  serf = 4648
}

server {
  enabled = false
}

client {
  enabled = true
  node_pool = "default"
  
  # Docker æ”¯æŒ
  cni {
    enabled = true
  }
}

# ç›‘æŽ§
telemetry {
  prometheus_metrics = true
}
