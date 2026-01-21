module VerticalMarker
  def self.add_vertical_markers!(g, output_path, indices, points_count, color: '#000000', width: 1)
    graph_left   = g.instance_variable_get(:@graph_left)
    graph_right  = g.instance_variable_get(:@graph_right)
    graph_top    = g.instance_variable_get(:@graph_top)
    graph_bottom = g.instance_variable_get(:@graph_bottom)
    # datasets = g.instance_variable_get(:@column_count)

    # puts g
    x_step = (graph_right - graph_left) / (points_count - 1)

    img = Magick::Image.read(output_path).first
    draw = Magick::Draw.new
    draw.stroke(color)
    draw.stroke_width(width)

    indices.each do |i|
      x = graph_left + i * x_step
      draw.line(x, graph_top, x, graph_bottom)
    end

    draw.draw(img)
    img.write(output_path)
  end

  # # Usage:
  # path = 'chart.png'
  # g.write(path)
  # add_vertical_markers!(g, path, [1, 3], color: '#0ea5e9', width: 2)

end