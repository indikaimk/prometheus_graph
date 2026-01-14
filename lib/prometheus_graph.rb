# frozen_string_literal: true
require_relative "prometheus_graph/version"
require_relative 'prometheus_graph/prom_client'
require_relative 'prometheus_graph/graph_renderer'

module PrometheusGraph
  class Error < StandardError; end
    class << self
      attr_accessor :configuration
    end

    def self.configure
      self.configuration ||= Configuration.new
      yield(configuration)
    end

    class Configuration
      attr_accessor :prom_url #, :param_2
    end
end
