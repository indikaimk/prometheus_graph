require 'gruff'
require_relative './prom_client'

module PrometheusGraph
  class GraphRenderer
    def initialize()
      @client = PrometheusGraph::PromClient.new
    end

    def create_line_chart(title: "Prometheus Metrics", 
                          query: "process_cpu_seconds_total", 
                          start_time: Time.now - (24 * 60 * 60), 
                          end_time: Time.now,
                          step: '5m',
                          output_file: "output/line_chart.png")

      data = @client.query_range(query: query, start_time: start_time, end_time: end_time, step: step)
      render_line_chart(data, title: title, output_file: output_file)

    end

    def render_line_chart(data_packet, title: "Prometheus Metrics", width: 800, output_file: 'chart.png')
      return puts "No data to render" if data_packet.nil?

      g = Gruff::Line.new(width)
      g.title = title
      g.theme_37signals
      g.marker_font_size = 12

      # 1. Add the Data Series
      data_packet[:series].each do |s|
        g.data(s[:label], s[:values])
      end

      # 2. Refined X-Axis Logic
      # We pass the raw unix timestamps to generate a label hash
      g.labels = generate_labels(data_packet[:timestamps])

      g.write(output_file)
    end

    private

    def generate_labels(timestamps)
      # Gruff expects a hash: { index => "Label String" }
      # We don't want to label every point (too messy), just ~5-7 key points.
      
      total_points = timestamps.size
      label_count = 6 # We want roughly 6 labels on the X-axis
      step_size = (total_points / label_count.to_f).ceil
      
      labels = {}

      timestamps.each_with_index do |ts, index|
        # Only add a label if it matches our step size
        if index % step_size == 0
          # Format: HH:MM for short durations, or MM-DD HH:MM for longer ones
          formatted_time = Time.at(ts).strftime("%H:%M") 
          labels[index] = formatted_time
        end
      end

      # Ensure the very last timestamp is always labeled for clarity
      last_index = total_points - 1
      labels[last_index] = Time.at(timestamps.last).strftime("%H:%M")

      labels
    end
  end
end