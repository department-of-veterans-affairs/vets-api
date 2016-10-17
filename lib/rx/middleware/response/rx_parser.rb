# frozen_string_literal: true
module Rx
  module Middleware
    module Response
      # class responsible for customizing parsing
      class RxParser < Faraday::Response::Middleware
        def on_complete(env)
          if env.response_headers['content-type'] =~ /\bjson/
            env[:body] = parse(env.body) unless env.body.blank?
          end
        end

        def parse(body = nil)
          @parsed_json = body
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
      end
    end
  end
end

Faraday::Response.register_middleware rx_parser: Rx::Middleware::Response::RxParser
