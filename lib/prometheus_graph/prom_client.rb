require 'prometheus/api_client'
require 'date'
require 'logger'
require 'openssl'

module PrometheusGraph
  class PromClient
    def initialize(logger: Logger.new($stdout), cert_file: nil)
      @logger = logger
      ssl_params = get_ssl_params(cert_file)
      @config = PrometheusGraph.configuration
      @client = Prometheus::ApiClient.client(url: @config.prom_url, ssl: ssl_params)
    end

    def query_range(query:, start_time:, end_time:, step: '1h')
      queries = query.is_a?(Array) ? query : [query]

      combined_series = []
      common_timestamps = nil

      # 2. Iterate through every query provided
      queries.each do |query|
        # puts legend_prefix
        response = @client.query_range(
          query: query[:query],
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
        parsed = parse_single_result(response['result'], query[:legend_template])
        
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

    # Create a hash of SSL params for Prometheus API client
    def get_ssl_params(cert_file)
      if cert_file
        # 1. Create a custom certificate store
        cert_store = OpenSSL::X509::Store.new
        cert_store.set_default_paths # Keep standard internet certs working

        # 2. Add your self-signed Prometheus certificate
        @logger.info("[PrometheusGraph] Loading certificate file #{cert_file}")
        cert_store.add_file(cert_file)

        return {cert_store: cert_store}
      else
        @logger.warn("[PrometheusGraph] No Certificate file provided")
        return {}
      end
    end

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

    def parse_single_result(raw_results, legend_template)
      timestamps = raw_results.first['values'].map { |v| v[0] }

      series_data = raw_results.map do |res|
        # Generate the standard Prometheus label (e.g. "instance=x,job=y")
        # raw_label = format_label(res['metric'], legend_template)
        raw_label = format_legend(res['metric'], legend_template)
        
        # If the user provided a prefix (from the Hash key), prepend it.
        # Result: "Errors - instance=x" vs "instance=x"
        # final_label = prefix.empty? ? raw_label : "#{prefix} #{raw_label}"
        # final_label = prefix.empty? ? raw_label : prefix

        {
          label: raw_label,
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

    def format_legend(metric_hash, template)
      # 1. The Fallback
      # If the user didn't write a legend template in the DSL, we generate a 
      # clean default string by joining all labels (except the internal __name__)
      if template.nil? || template.strip.empty?
        return metric_hash.reject { |k, _| k == "__name__" }
                          .map { |k, v| "#{k}=\"#{v}\"" }
                          .join(", ")
      end

      # 2. The Template Engine
      # Look for anything inside double curly braces, capture the word inside,
      # and swap it with the corresponding value from the Prometheus HTTP response.
      template.gsub(/\{\{([a-zA-Z0-9_]+)\}\}/) do |match|
        label_key = $1 # Extracts the exact string inside the braces (e.g., "instance")
        
        # We use .fetch so that if the user makes a typo in their DSL (like {{instence}}), 
        # it safely prints "unknown" instead of throwing a Nil error or crashing the graph.
        metric_hash.fetch(label_key, "unknown")
      end
    end
  end
end