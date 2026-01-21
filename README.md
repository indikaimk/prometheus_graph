# A Ruby gem for creating PNG images from Prometheus metrics

 `prometheus-graph` is a Ruby gem that bridges the gap between raw Prometheus metrics and shareable visualizations. It allows you to query a Prometheus instance and generate static PNG charts programmatically—perfect for Slack bots, email reports, or automated dashboards.


## Features

* **Simple API**: Split into `Client` (for fetching) and `Renderer` (for drawing) for flexibility.
* **Time-Series Visualization**: Automatically handles Prometheus range vectors.
* **Smart Labeling**: Auto-calculates X-Axis timestamps to prevent label overcrowding.
* **Gruff Integration**: Uses the powerful Gruff library (via ImageMagick) for clean, professional charts.

## Prerequisites

Since this gem uses `gruff` for image generation, you must have **ImageMagick** installed on your system.

**macOS**
```bash
brew install imagemagick

```

**Ubuntu/Debian**

```bash
sudo apt-get install libmagickwand-dev

```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'prometheus_graph'

```

And then execute:

```bash
$ bundle install

```

Or install it yourself as:

```bash
$ gem install prometheus_graph

```

## Usage

The gem is designed with two main components: a **Client** to fetch the data and a **Renderer** to draw it.

### 1. Basic Example

Here is a quick script to fetch CPU usage over the last 6 hours and save it to an image.

```ruby
require 'prometheus_graph'

# 1. Configure the Client
# Replace with your Prometheus URL
client = PrometheusGraph::Client.new(url: 'http://localhost:9090') 

# 2. Fetch Data
# Query: 100 - (avg by (instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
data = client.query_range(
  query: 'process_resident_memory_bytes', 
  start_time: Time.now - (6 * 60 * 60), # 6 hours ago
  end_time: Time.now,
  step: '5m' # Resolution
)

# 3. Render the Graph
renderer = PrometheusGraph::Renderer.new(
  title: "Memory Usage (Last 6 Hours)",
  width: 1000
)

renderer.render(data, output_file: 'memory_report.png')

puts "Graph saved to memory_report.png!"

```

### 2. Customizing the Renderer

You can adjust the graph title and width during initialization.

```ruby
renderer = PrometheusGraph::Renderer.new(
  title: "Production Traffic", 
  width: 1200
)

```

The `render` method automatically handles:

* **Series Labeling**: Based on Prometheus metric tags (e.g., `instance`, `job`).
* **Timestamp formatting**: Converts Unix timestamps to readable `HH:MM` format on the X-Axis.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/indikaimk/prometheus_graph.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
