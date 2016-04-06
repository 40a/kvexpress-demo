#!/bin/bash
sudo mkdir -p /etc/consul-template/{config,output,templates}

DD_API_KEY=$(cat /tmp/datadog-api-key)
DD_APP_KEY=$(cat /tmp/datadog-app-key)

cat > /tmp/kvexpress.yaml <<EOF
---
  datadog_api_key: $DD_API_KEY
  datadog_app_key: $DD_APP_KEY
  consul_server:
  token:
  dogstatsd: true
  dogstatsd_address:
  datadog_host: https://app.datadoghq.com
EOF
sudo mv -f /tmp/kvexpress.yaml /etc/kvexpress.yaml

cat > /tmp/hosts.cfg <<EOF
consul = "127.0.0.1:8500"
retry = "10s"
max_stale = "5s"
wait = "10s"
log_level = "debug"

syslog {
  enabled = true
  facility = "LOCAL5"
}

template {
  source = "/etc/consul-template/templates/hosts.ctmpl"
  destination = "/etc/consul-template/output/config_hosts"
  command = "KVEXPRESS_DEBUG=1 /usr/local/bin/kvexpress in -C /etc/kvexpress.yaml --file='/etc/consul-template/output/config_hosts' --key='hosts' --length=10 --sorted true"
}
EOF
sudo mv -f /tmp/hosts.cfg /etc/consul-template/config/hosts.cfg

cat > /tmp/hosts.ctmpl <<EOF
{{range ls "kvexpresshosts/services/"}}
{{range \$tag, \$services := service .Key | byTag}}
{{range \$services}}{{.Address}} {{\$tag}}.{{.Name}}.service.consul
{{end}}{{end}}
{{range service .Key}}{{.Address}} {{.Name}}.service.consul
{{end}}
{{end}}
EOF
sudo mv -f /tmp/hosts.ctmpl /etc/consul-template/templates/hosts.ctmpl

cat > /tmp/kvexpresshosts.conf <<EOF
description "kvexpress hosts file distribution"

# Defaults set by kernel
limit nofile 1024 4096

emits kvexpresshosts-up

start on runlevel [2345]
stop on runlevel [!2345]

exec consul lock -n 1 kvexpresshosts /usr/local/bin/consul-template -config /etc/consul-template/config/hosts.cfg

post-start exec initctl emit kvexpresshosts-up

kill signal INT
EOF
sudo mv -f /tmp/kvexpresshosts.conf /etc/init/kvexpresshosts.conf

sudo ln -s /lib/init/upstart-job /etc/init.d/kvexpresshosts
