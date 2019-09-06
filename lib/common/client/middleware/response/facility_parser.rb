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
            path_test = env.url.path.match(%r(\/([\w]{3}_(Facilities|VetCenters))\/))
            path_test = env.url.path.match(/(FacilitySitePoint_\w{3})/) if path_test.nil?
            path_part = path_test[1]
            facility_map = facility_klass(path_part).attribute_map
            env.body['features'].map { |location_data| TempFacility.new(location_data, facility_map).build_facility_attributes }
          end

          def facility_klass(path_part)
            BaseFacility::PATHMAP[path_part]
          end

          class TempFacility
            attr_accessor :facility, :location, :mapping

            def initialize(location_data, facility_map)
              @location = location_data
              @mapping = facility_map

              @facility = { 
                'address' => {},
                'services' => {},
                'lat' => @location['geometry']['y'],
                'long' => @location['geometry']['x'] 
              }
            end

            def build_facility_attributes
              make_direct_mappings
              make_complex_mappings
              @facility['address'] = make_address_mappings
              @facility['services']['benefits'] = map_benefits_services if @mapping['benefits']
              @facility['hours'] = make_hours_mappings
              @facility['services'] = map_health_services if @mapping['services']
              
              @facility
            end

            def make_direct_mappings
              %w[unique_id name classification website].each_with_object({}) do |name, attributes|
                @facility[name] = strip(@location['attributes'][@mapping[name]])
              end
            end

            def make_complex_mappings
              %w[access feedback phone].each_with_object({}) do |name, attributes|
                @facility[name] = complex_mapping(name)
              end
            end

            def make_address_mappings
              { 
                'physical' => complex_mapping('physical'),
                'mailing' => complex_mapping('mailing')
              }
            end

            def map_benefits_services
              {
                'standard' => calculate_standard_benefits,
                'other' => @location['attributes']['Other_Services']
              }
            end

            def calculate_standard_benefits
              cleaned_benefits = clean_benefits(complex_mapping('benefits'))
              cleaned_benefits << 'Pensions' if has_pensions?
              cleaned_benefits
            end

            def has_pensions?
              BaseFacility::PENSION_LOCATIONS.include?(@facility['unique_id'])
            end

            def make_hours_mappings
              hours_mapping = complex_mapping('hours')
              hours_mapping.transform_values! do |hours|
                if /closed/i.match(hours) || hours == '-'
                  'Closed'
                else
                  hours
                end
              end

              hours_mapping
            end

            def map_health_services
              {
                'last_updated' => services_date,
                'health' => collect_health_services,
                'other' => []
              }
            end

            def complex_mapping(attr_name)
              attrs = @location['attributes']
              item = @mapping[attr_name]
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

            def services_date
              id = @facility['unique_id'].upcase
              facility_wait_time = FacilityWaitTime.find(id)

              if facility_wait_time&.source_updated.present?
                Date.strptime(facility_wait_time&.source_updated).iso8601
              end
            end

            def collect_health_services
              services = []

              id = @facility['unique_id'].upcase
              services << services_from_wait_time_data(id)
              services << dental_services(id)

              services.flatten
            end

            def services_from_wait_time_data(facility_id)
              facility_wait_time = FacilityWaitTime.find(facility_id)
              metric_keys = facility_wait_time&.metrics&.keys || []
              services = []
              services << { 'sl1' => ['EmergencyCare'], 'sl2' => [] } if facility_wait_time&.emergency_care&.any?
              services << { 'sl1' => ['UrgentCare'], 'sl2' => [] } if facility_wait_time&.urgent_care&.any?
              Facilities::AccessDataDownload::WT_KEY_MAP.each_value do |service|
                services << { 'sl1' => [service.camelize], 'sl2' => [] } if metric_keys.include?(service)
              end
              services
            end

            def dental_services(facility_id)
              services = []
              if FacilityDentalService.exists?(facility_id)
                services << { 'sl1' => ['DentalServices'], 'sl2' => [] }
              end

              services
            end
          end

        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_parser: Common::Client::Middleware::Response::FacilityParser
