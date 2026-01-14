require 'prometheus/api_client'
require 'date'

module PrometheusGraph
  class PromClient
    def initialize()
      @config = PrometheusGraph.configuration
      @client = Prometheus::ApiClient.client(url: @config.prom_url)
    end

    def query_range(query:, start_time:, end_time:, step: '1h')
      response = @client.query_range(
        query: query,
        start: start_time.iso8601,
        end: end_time.iso8601,
        step: step
      )
      
      parse_response(response)
    end

    private

    def parse_response(response)
      raw_results = response['result']
      return nil if raw_results.nil? || raw_results.empty?

      # We assume all series share the same timestamps if the query is aligned.
      # We grab the timestamps from the first result to build our X-Axis key.
      timestamps = raw_results.first['values'].map { |v| v[0] }

      series_data = raw_results.map do |res|
        {
          label: format_label(res['metric']),
          # Map values to Float, handle "NaN" if necessary
          values: res['values'].map { |v| v[1].to_f }
        }
      end

      { timestamps: timestamps, series: series_data }
    end

    def format_label(metric_hash)
      # Prefer 'instance' or 'job', otherwise flatten the hash
      return metric_hash['instance'] if metric_hash['instance']
      return metric_hash['job'] if metric_hash['job']
      metric_hash.map { |k, v| "#{k}=#{v}" }.join(",")
    end
  end
end