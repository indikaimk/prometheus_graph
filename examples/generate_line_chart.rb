require_relative '../lib/prometheus_graph'

PrometheusGraph.configure do |config|
  config.prom_url = 'http://127.0.0.1:9090'
end

renderer = PrometheusGraph::GraphRenderer.new
renderer.create_line_chart(query: "process_virtual_memory_bytes")
