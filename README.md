# Prometheus Graph - A Ruby gem for creating PNG images from Prometheus metrics

 `prometheus-graph` is a Ruby gem that bridges the gap between raw Prometheus metrics and shareable visualizations. It allows you to query a Prometheus instance and generate static PNG charts programmatically—perfect for Slack bots, email reports, or automated dashboards.


## Features

* **Multi-Series Support**: Overlay multiple PromQL queries on a single chart (e.g., Inbound vs Outbound traffic).
* **Smart Visualization**: Automatically handles time-series data, detects "No Data" scenarios, and renders "Ghost Series" for missing metrics.
* **Auto-Scaling**: Automatically scales Y-Axis units (e.g., converts `1,000,000` bits/s to `1 Mb/s`) for human readability.
* **Intelligent X-Axis**: Auto-calculates timestamp labels to prevent overcrowding, supporting durations from minutes to weeks.
* **Highly Configurable**: Custom themes, colors, and logging support.

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
PrometheusGraph.configure do |config|
  config.prom_url = 'http://127.0.0.1:9090' #Prometheus URL
  config.theme = :light # Use light theme. Set to :dark for dark theme.
end

# 2. Run PromQL query and create graph

renderer = PrometheusGraph::GraphRenderer.new
renderer.create_line_chart(query: "sum(rate(ifHCInOctets[6m]) * 8)") 
```

### 2. Multiple PromQL queries

You can compare different metrics on the same chart by passing a Hash of queries. The keys become the legend prefixes.

```ruby
queries = {
  "Success" => 'rate(http_requests_total{status="200"}[5m])',
  "Errors"  => 'rate(http_requests_total{status="500"}[5m])'
}

PrometheusGraph.configure do |config|
  config.prom_url = 'http://127.0.0.1:9090'
  config.theme = :light
end

renderer = PrometheusGraph::GraphRenderer.new
renderer.create_line_chart(query: queries)
```

#### Pro Tip

If your query returns too many lines (e.g., CPU usage for 50 containers), the graph will be unreadable. Use the Prometheus topk operator to limit the results.

```ruby
# Only graph the top 5 CPU consumers
query = 'topk(5, rate(node_cpu_seconds_total[5m]))'
```

## Configuration

### Logging

By default, the **Prometheus Graph** logs warnings to STDOUT. You can pass a custom Logger (e.g., to write to a file) when initializing the client.

```ruby
require 'logger'

# Log warnings to a file
bot_logger = Logger.new('bot.log')

client = PrometheusGraph::Client.new(
  url: 'http://localhost:9090', 
  logger: bot_logger
)
```

### Customizing the Renderer

You can adjust the graph title and pixel width at the graph creation time.

```ruby
renderer.create_line_chart(query: "sum(rate(ifHCInOctets[6m]) * 8)", title: "Network throughput", width: 1200)
```

The `render` method automatically handles:

* **Series Labeling**: Based on Prometheus metric tags (e.g., `instance`, `job`).
* **Timestamp formatting**: Converts Unix timestamps to readable `HH:MM` format on the X-Axis.

## Handling Missing Data

Complete Failure: If all queries fail, the gem generates a placeholder image displaying "NO DATA FOUND".

Partial Failure: If one query fails but others succeed, the failed query is logged.

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/indikaimk/prometheus_graph.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).


