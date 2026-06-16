# frozen_string_literal: true

require 'json'

module RedmineReformat
  module Converters
    class << self
      def from_json(json)
        cfg = JSON.parse(json, symbolize_names: true)
        RedmineReformat::Converters::ConfiguredConverters.new(cfg) if cfg
      end
    end
  end
end
