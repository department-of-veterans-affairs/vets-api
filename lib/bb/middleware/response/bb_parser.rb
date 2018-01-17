# frozen_string_literal: true

module BB
  module Middleware
    module Response
      # class responsible for customizing parsing
      class BBParser < Faraday::Response::Middleware
        def on_complete(env)
          return unless env.response_headers['content-type'] =~ /\bjson/
          # If POST is successful message body is irrelevant
          # if it was not successul an exception would have already been raised
          return if env.method == :post
          env[:body] = parse(env.body) if env.body.present?
        end

        def parse(body = nil)
          @parsed_json = body
          @meta_attributes = split_meta_fields!
          @errors = @parsed_json.delete(:errors) || {}

          data =  parsed_extract_status_list || parsed_health_record_types
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

        def parsed_extract_status_list
          return nil unless @parsed_json.keys.include?(:facility_extract_status_list)
          @parsed_json[:facility_extract_status_list]
        end

        def parsed_health_record_types
          return nil unless @parsed_json.keys.include?(:data_classes)
          @parsed_json
        end
      end
    end
  end
end

Faraday::Response.register_middleware bb_parser: BB::Middleware::Response::BBParser
