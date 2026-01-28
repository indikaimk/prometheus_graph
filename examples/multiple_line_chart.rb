require_relative '../lib/prometheus_graph'

# Comparing Inbound vs Outbound Traffic
# queries = {
#   "Inbound"  => 'rate(node_network_receive_bytes_total{device="eth0"}[5m])',
#   "Outbound" => 'rate(node_network_transmit_bytes_total{device="eth0"}[5m])'
# }

queries = {
  "Inbound"  => 'rate(process_network_receive_bytes_total[5m])',
  "Outbound" => 'rate(process_network_transmit_bytes_total[5m])'
}

PrometheusGraph.configure do |config|
  config.prom_url = 'http://127.0.0.1:9090'
  config.theme = :light
end

renderer = PrometheusGraph::GraphRenderer.new
image = renderer.create_line_chart(query: queries)
puts image.filename
