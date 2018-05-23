# frozen_string_literal: true

require 'facility_access'

module Common
  module Client
    module Middleware
      module Response
        class FacilityParser < Faraday::Response::Middleware
          def on_complete(env)
            env.body = parse_body(env)
          end

          private

          def parse_body(env)
            path_part = env.url.path.match(%r(\/([\w]{3}_(Facilities|VetCenters))\/))[1]
            facility_map = BaseFacility::PATHMAP[path_part]
            env.body['features'].map { |location_data| build_facility_attributes(location_data, facility_map) }
          end

          def build_facility_attributes(location, mapping)
            facility = { 'address' => {},
                         'services' => {},
                         'lat' => location['geometry']['y'],
                         'long' => location['geometry']['x'] }
            facility.merge!(make_direct_mappings(location, mapping))
            facility.merge!(make_complex_mappings(location, mapping))
            facility.merge!(make_address_mappings(location, mapping))
            facility.merge!(make_benefits_mappings(location, mapping)) if mapping['benefits']
            facility.merge!(make_service_mappings(location, mapping)) if mapping['services']
            facility
          end

          def make_direct_mappings(location, mapping)
            %w[unique_id name classification website].each_with_object({}) do |name, attributes|
              attributes[name] = strip(location['attributes'][mapping[name]])
            end
          end

          def make_complex_mappings(location, mapping)
            %w[hours access feedback phone].each_with_object({}) do |name, attributes|
              attributes[name] = complex_mapping(mapping[name], location['attributes'])
            end
          end

          def make_address_mappings(location, mapping)
            attributes = {}
            attributes['physical'] = complex_mapping(mapping['physical'], location['attributes'])
            attributes['mailing'] = complex_mapping(mapping['mailing'], location['attributes'])
            { 'address' => attributes }
          end

          def make_benefits_mappings(location, mapping)
            attributes = {}
            attributes['benefits'] = {
              'standard' => clean_benefits(complex_mapping(mapping['benefits'], location['attributes'])),
              'other' => location['attributes']['Other_Services']
            }
            { 'services' => attributes }
          end

          def make_service_mappings(location, mapping)
            attributes = {}
            attributes['last_updated'] = services_date(location['attributes'])
            attributes['health'] = services_from_gis(mapping['services'], location['attributes'])
            { 'services' => attributes }
          end

          def complex_mapping(item, attrs)
            return {} unless item
            item.each_with_object({}) do |(key, value), hash|
              hash[key] = value.respond_to?(:call) ? value.call(attrs) : strip(attrs[value])
            end
          end

          def clean_benefits(benefits_hash)
            benefits_hash.keys.select { |key| benefits_hash[key] == BaseFacility::YES }
          end

          def strip(value)
            value.respond_to?(:strip) ? value.strip : value
          end

          def services_date(attrs)
            Date.strptime(attrs['FacilityDataDate'], '%m-%d-%Y').iso8601 if attrs['FacilityDataDate']
          end

          def services_from_gis(service_map, attrs)
            return unless service_map
            services = service_map.each_with_object([]) do |(k, v), l|
              next unless attrs[k] == BaseFacility::YES && BaseFacility::APPROVED_SERVICES.include?(k)
              sl2 = []
              v.each do |sk|
                sl2 << sk if attrs[sk] == BaseFacility::YES && BaseFacility::APPROVED_SERVICES.include?(sk)
              end
              l << { 'sl1' => [k], 'sl2' => sl2 }
            end
            services.concat(services_from_wait_time_data(attrs['StationNumber'].upcase))
          end

          def services_from_wait_time_data(facility_id)
            facility_wait_time = FacilityWaitTime.find(facility_id)
            metric_keys = facility_wait_time&.metrics&.keys || []
            services = []
            services << { 'sl1' => ['EmergencyCare'], 'sl2' => [] } if facility_wait_time&.emergency_care&.any?
            services << { 'sl1' => ['UrgentCare'], 'sl2' => [] } if facility_wait_time&.urgent_care&.any?
            services << { 'sl1' => ['Audiology'], 'sl2' => [] } if metric_keys.include?('audiology')
            services << { 'sl1' => ['Optometry'], 'sl2' => [] } if metric_keys.include?('optometry')
            services
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_parser: Common::Client::Middleware::Response::FacilityParser
