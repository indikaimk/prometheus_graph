require 'prometheus/api_client'
require 'date'
require 'logger'

module PrometheusGraph
  class PromClient
    def initialize(logger: Logger.new($stdout))
      @config = PrometheusGraph.configuration
      @client = Prometheus::ApiClient.client(url: @config.prom_url)
      @logger = logger
    end

    def query_range(query:, start_time:, end_time:, step: '1h')
      queries = query.is_a?(Hash) ? query : { "" => query }

      combined_series = []
      common_timestamps = nil

      # 2. Iterate through every query provided
      queries.each do |legend_prefix, promql|
        response = @client.query_range(
          query: promql,
          start: start_time.iso8601,
          end: end_time.iso8601,
          step: step
        )

        # 1. Safe Empty Check
        # Guards against nil 'response' AND nil/empty 'result'
        if response.nil? || (response['result'] || []).empty?
          @logger.warn("[PrometheusGraph] No data found for query: '#{promql}'")
          next
        end

        # 2. Parse
        parsed = parse_single_result(response['result'], legend_prefix)
        
        # 3. Capture timestamps from the first SUCCESSFUL query
        common_timestamps ||= parsed[:timestamps]
        
        combined_series.concat(parsed[:series])
      end

      return nil if combined_series.empty?

      { timestamps: common_timestamps, series: combined_series }

      # response = @client.query_range(
      #   query: query,
      #   start: start_time.iso8601,
      #   end: end_time.iso8601,
      #   step: step
      # )
      
      # parse_response(response)
    end

    private

    # def parse_response(response)
    #   raw_results = response['result']
    #   return nil if raw_results.nil? || raw_results.empty?

    #   # We assume all series share the same timestamps if the query is aligned.
    #   # We grab the timestamps from the first result to build our X-Axis key.
    #   timestamps = raw_results.first['values'].map { |v| v[0] }

    #   series_data = raw_results.map do |res|
    #     {
    #       label: format_label(res['metric']),
    #       # Map values to Float, handle "NaN" if necessary
    #       values: res['values'].map { |v| v[1].to_f }
    #     }
    #   end

    #   { timestamps: timestamps, series: series_data }
    # end

    def parse_single_result(raw_results, prefix)
      timestamps = raw_results.first['values'].map { |v| v[0] }

      series_data = raw_results.map do |res|
        # Generate the standard Prometheus label (e.g. "instance=x,job=y")
        raw_label = format_label(res['metric'])
        
        # If the user provided a prefix (from the Hash key), prepend it.
        # Result: "Errors - instance=x" vs "instance=x"
        final_label = prefix.empty? ? raw_label : "#{prefix} #{raw_label}"

        {
          label: final_label,
          values: res['values'].map { |v| v[1].to_f }
        }
      end

      { timestamps: timestamps, series: series_data }
    end

    # def format_label(metric_hash)
    #   # Prefer 'instance' or 'job', otherwise flatten the hash
    #   return metric_hash['instance'] if metric_hash['instance']
    #   return metric_hash['job'] if metric_hash['job']
    #   metric_hash.map { |k, v| "#{k}=#{v}" }.join(",")
    # end

    def format_label(metric_hash)
      # Return 'instance' if it's the only useful tag, otherwise join them all
      return metric_hash['instance'] if metric_hash.size == 1 && metric_hash['instance']
      
      # Remove the internal '__name__' tag if present to keep it clean
      tags = metric_hash.reject { |k, _| k == '__name__' }
      tags.map { |k, v| "#{k}=#{v}" }.join(",")
    end
  end
end