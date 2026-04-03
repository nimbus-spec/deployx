# Nomad Server Configuration
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
  enabled = true
  bootstrap_expect = 1
}

client {
  enabled = false
}

# ç½‘ç»œ
enable_raft_rpc = true

# ç›‘æŽ§
telemetry {
  prometheus_metrics = true
}

# TLS (ç”Ÿäº§çŽ¯å¢ƒå»ºè®®å¯ç”¨)
# tls {
#   http = true
#   rpc  = true
# }
