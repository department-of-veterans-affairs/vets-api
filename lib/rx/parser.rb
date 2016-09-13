# frozen_string_literal: true
require 'multi_json'

module Rx
  # class responsible for customizing parsing
  class Parser
    def initialize(parsed_json)
      @parsed_json = parsed_json
    end

    def parse!
      snakecase!
      @meta_attributes = split_meta_fields!
      @errors = @parsed_json.delete(:errors) || {}

      data =  parsed_prescription_list || parsed_tracking_object || parsed_prescription
      @parsed_json = {
        data: data,
        errors: @errors,
        metadata: @meta_attributes
      }
      @parsed_json
    end

    def split_meta_fields!
      updated_at = @parsed_json.delete(:last_updated_time) ||
                   @parsed_json.delete(:last_updatedtime)

      # TODO: possibly add default Time.now.utc (maybe in struct)
      {
        updated_at: updated_at,
        failed_station_list: @parsed_json.delete(:failed_station_list)
      }
    end

    def parsed_prescription
      return nil unless @parsed_json.keys.include?(:refill_status)
      @parsed_json
    end

    def parsed_prescription_list
      return nil unless @parsed_json.keys.include?(:prescription_list)
      @parsed_json[:prescription_list]
    end

    def parsed_tracking_object
      return nil unless @parsed_json.keys.include?(:tracking_info)
      infos, base = @parsed_json.partition { |k, _| k == :tracking_info }
      Hash[infos][:tracking_info].map do |tracking_info|
        Hash[base].merge(tracking_info.except(:other_prescription_list_included))
      end
    end

    def snakecase
      case @parsed_json
      when Array
        @parsed_json.map { |hash| underscore_symbolize(hash) }
      when Hash
        underscore_symbolize(@parsed_json)
      end
    end

    def snakecase!
      @parsed_json = snakecase
    end

    private

    def underscore_symbolize(hash)
      hash.deep_transform_keys { |k| k.underscore.to_sym }
    end
  end
end
