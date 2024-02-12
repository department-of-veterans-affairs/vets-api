# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class FacilityValidator < Faraday::Response::Middleware
          def on_complete(env)
            env.body = validate_body(env)
          end

          private

          def validate_body(env)
            json_body = Oj.load(env.body)
            if BaseFacility.validate_on_load
              path_test = env.url.path.match(%r(/(\w{3}_(Facilities|VetCenters))/))
              path_test = env.url.path.match(/(FacilitySitePoint_\w{3})/) if path_test.nil?
              path_part = path_test[1]

              facility_map = facility_klass(path_part).attribute_map
              validate(json_body['features'], facility_map)
            end
            json_body
          rescue Oj::Error => e
            raise Common::Client::Errors::ParsingError, e
          end

          def validate(locations, map)
            id_list = locations.each_with_object(Hash.new(0)) do |location, ids|
              ids[location['attributes'][map['unique_id']]] += 1
              ensure_geometry(location['geometry'])
              ensure_mapped_fields(location['attributes'].keys, map['mapped_fields'])
            end
            ensure_uniqueness(id_list)
          end

          def ensure_geometry(geometry)
            raise_invalid_error('missing geometry') if geometry.nil? || geometry['x'].nil? || geometry['y'].nil?
          end

          def ensure_mapped_fields(keys, fields)
            raise_invalid_error('missing mapped fields') if (fields - keys).any?
          end

          def ensure_uniqueness(ids)
            raise_invalid_error('duplicate ids') if ids.select { |_k, v| v > 1 }.any?
          end

          def raise_invalid_error(message)
            raise Common::Client::Errors::ParsingError, "invalid source data: #{message}"
          end

          def facility_klass(path_part)
            Facilities::Mappings::PATHMAP[path_part]
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_validator: Common::Client::Middleware::Response::FacilityValidator
