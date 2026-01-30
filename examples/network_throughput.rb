require_relative '../lib/prometheus_graph'

# Comparing Inbound vs Outbound Traffic
# queries = {
#   "Inbound"  => 'rate(node_network_receive_bytes_total{device="eth0"}[5m])',
#   "Outbound" => 'rate(node_network_transmit_bytes_total{device="eth0"}[5m])'
# }

queries = {
  "Inbound"  => 'sum(rate(ifHCInOctets{instance=~".*_router_.*", ifAlias=~".*FW.*", ifName=~".*100GE.*"}[5m])*8)',
  "Outbound" => 'sum(rate(ifHCOutOctets{instance=~".*_router_.*", ifAlias=~".*FW.*", ifName=~".*100GE.*"}[5m])*8)'
}

PrometheusGraph.configure do |config|
  config.prom_url = 'http://127.0.0.1:9090'
  config.theme = :light
end

renderer = PrometheusGraph::GraphRenderer.new
image = renderer.create_line_chart(query: queries, start_time: Time.now - (2 * 24 * 60 * 60))
puts image.filename
