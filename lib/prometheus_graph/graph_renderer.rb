require 'gruff'
require_relative './prom_client'
require_relative './humanizer'
require_relative './vertical_marker'

module PrometheusGraph
  class GraphRenderer
    def initialize()
      @config = PrometheusGraph.configuration
      @client = PrometheusGraph::PromClient.new
      @theme = PrometheusGraph.configuration.theme || :dark
    end

    def create_line_chart(title: "Prometheus Metrics", 
                          query: "process_cpu_seconds_total", 
                          start_time: Time.now - (24 * 60 * 60), 
                          end_time: Time.now,
                          step: '5m',
                          output_file: "output/line_chart.png",
                          y_axis_datatype: :number,
                          width: 1800)

      data = @client.query_range(query: query, start_time: start_time, end_time: end_time, step: step)
      render_line_chart(data, title: title, output_file: output_file)
    end

    def render_line_chart(data_packet, title: "Prometheus Metrics", width: 1800, output_file: 'chart.png')
      return puts "No data to render" if data_packet.nil?

      g = Gruff::Line.new(width)
      g.title = title
      # g.theme_37signals
      # g.marker_font_size = 12

      # 1. Clean up the lines
      g.line_width = 1
      g.hide_dots = true # Essential for high-resolution Prometheus data
      # g.baseline_value = 0 # Optional: Helps if you want to ground the graph. will add a thick dotted line along x axis
      g.show_vertical_markers = true
      g.marker_x_count = 24

      # 2. Typography
      g.title_font_size = 24
      g.marker_font_size = 14
      g.legend_font_size = 14
      g.legend_box_size = 12 # Size of the colored box in the legend

      # 3. Margins (Give the graph room to breathe)
      g.top_margin = 20
      g.bottom_margin = 40
      g.left_margin = 40
      g.right_margin = 40

      apply_theme(g)
      # 1. Add the Data Series
      # data_packet[:series].each do |s|
      #   g.data(s[:label], s[:values])
      # end

      scaled_data, unit = Humanizer.auto_scale(data_packet[:series])
      
      # Add the new unit to the Title or Y-Axis label
      # g.y_axis_label = unit 
      g.y_axis_label_format = ->(v) { format("%d #{unit}", v.round) }
      
      # Use the scaled data
      scaled_data.each do |s|
        g.data(s[:label], s[:values])
      end

      # 2. Refined X-Axis Logic
      # We pass the raw unix timestamps to generate a label hash
      g.labels = generate_labels(data_packet[:timestamps])
      # puts data_packet[:timestamps].count
      g.write(output_file)
      # VerticalMarker.add_vertical_markers!(g, output_file, [1, 3], data_packet[:timestamps].count, color: '#0ea5e9', width: 2)
    end

    private

    def apply_theme(g)
      case @theme
      when :dark
        # A modern dark theme (Slack/Discord style)
        g.theme = {
          colors: %w[#4facfe #00f2fe #fa709a #fee140 #a8edea], # Neon gradients
          marker_color: '#dddddd', # Axis text color
          font_color: '#ffffff',   # Title/Legend color
          background_colors: %w[#2b2b2b #1a1a1a] # Gradient background
        }
      when :light
        # A clean corporate light theme
        g.theme = {
          colors: %w[#0052CC #00B8D9 #36B37E #FFAB00 #FF5630], # Atlassian-ish colors
          marker_color: '#dadada',
          font_color: '#333333',
          background_colors: %w[#ffffff #f4f5f7]

        }
      end
    end

    # def generate_labels(timestamps)
    #   # Gruff expects a hash: { index => "Label String" }
    #   # We don't want to label every point (too messy), just ~5-7 key points.
      
    #   total_points = timestamps.size
    #   label_count = 6 # We want roughly 6 labels on the X-axis
    #   step_size = (total_points / label_count.to_f).ceil
      
    #   labels = {}

    #   timestamps.each_with_index do |ts, index|
    #     # Only add a label if it matches our step size
    #     if index % step_size == 0
    #       # Format: HH:MM for short durations, or MM-DD HH:MM for longer ones
    #       formatted_time = Time.at(ts).strftime("%H:%M") 
    #       labels[index] = formatted_time
    #     end
    #   end

    #   # Ensure the very last timestamp is always labeled for clarity
    #   last_index = total_points - 1
    #   labels[last_index] = Time.at(timestamps.last).strftime("%H:%M")

    #   labels
    # end

    def generate_labels(timestamps)
      return {} if timestamps.empty?

      labels = {}
      duration_seconds = timestamps.last - timestamps.first

      # 1. Determine Step Size (Targeting ~12 labels)
      target_labels = 12
      ideal_step_seconds = duration_seconds / target_labels
      
      # Updated steps to include daily/weekly intervals
      # 1h, 2h, 4h, 8h, 12h, 24h (1d), 48h (2d), 168h (1wk)
      nice_steps = [1, 2, 4, 8, 12, 24, 48, 168]
      step_hours = nice_steps.find { |h| (h * 3600) >= ideal_step_seconds } || 1

      # 2. Choose the Time Format based on Duration & Step
      time_format = get_time_format(duration_seconds, step_hours)

      # 3. First and Last labels
      labels[0] = Time.at(timestamps.first).strftime(time_format)
      last_idx = timestamps.size - 1
      labels[last_idx] = Time.at(timestamps.last).strftime(time_format)

      # 4. Iterate
      timestamps.each_with_index do |ts, index|
        next if index == 0 || index == last_idx

        current_time = Time.at(ts)
        prev_time = Time.at(timestamps[index - 1])

        # Logic: Only add label if we crossed a "Step Boundary"
        # e.g. if step is 4 hours, we check if current_time is divisible by 4
        if crossed_step_boundary?(current_time, prev_time, step_hours)
          labels[index] = current_time.strftime(time_format)
        end
      end

      labels
    end


    def get_time_format(duration_seconds, step_hours)
      if step_hours >= 24
        # If steps are 1 day or larger, don't show specific hours
        # e.g., "Jan 21"
        "%b %d"
      elsif duration_seconds > 86_400
        # If total duration > 24h but steps are smaller, show both
        # e.g., "Jan 21 14:00"
        "%b %d %H:%M"
      else
        # Standard Intra-day
        # e.g., "14:00"
        "%H:%M"
      end
    end

    def crossed_step_boundary?(current, previous, step_hours)
      # Different logic depending on if step is < 24h or >= 24h
      if step_hours < 24
        # Hour change logic
        current.hour != previous.hour && (current.hour % step_hours == 0)
      else
        # Day change logic (for long duration graphs)
        current.day != previous.day && (current.day % (step_hours / 24) == 0)
      end
    end
  end
end