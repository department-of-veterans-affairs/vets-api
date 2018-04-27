# frozen_string_literal: true

module Common
  module Client
    module Middleware
      module Response
        class FacilityValidator < Faraday::Response::Middleware
          include Facilities::FacilityMapping

          def on_complete(env)
            env.body = validate_body(env)
          end

          private

          def validate_body(env)
            json_body = Oj.load(env.body)
            if Facilities::FacilityMapping.validate_on_load
              facility_map = PATHMAP[env.url.path.match(%r(\/([\w]{3}_(Facilities|VetCenters))\/))[1]]
              validate(json_body['features'], facility_map)
            end
            json_body
          rescue Oj::Error => error
            raise Common::Client::Errors::ParsingError, error
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
            raise Common::Client::Errors::ValidationError, "invalid source data: #{message}"
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_validator: Common::Client::Middleware::Response::FacilityValidator
