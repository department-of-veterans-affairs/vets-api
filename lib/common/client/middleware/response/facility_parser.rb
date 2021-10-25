# frozen_string_literal: true

require 'facility_wait_time'

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
            path_test = env.url.path.match(%r(\/(\w{3}_(Facilities|VetCenters))\/))
            path_test = env.url.path.match(/(FacilitySitePoint_\w{3})/) if path_test.nil?
            path_part = path_test[1]
            facility_map = facility_klass(path_part).attribute_map
            env.body['features'].map do |location_data|
              TempFacility.new(location_data, facility_map).build_facility_attributes
            end
          end

          def facility_klass(path_part)
            BaseFacility::PATHMAP[path_part]
          end

          class TempFacility
            def initialize(location_data, facility_map)
              @src_facility = location_data
              @mapping = facility_map

              @dest_facility = {
                'address' => {},
                'services' => {},
                'lat' => @src_facility['geometry']['y'],
                'long' => @src_facility['geometry']['x']
              }
            end

            def build_facility_attributes
              make_direct_mappings
              make_complex_mappings
              @dest_facility['address'] = make_address_mappings
              @dest_facility['services']['benefits'] = map_benefits_services if @mapping['benefits']
              @dest_facility['hours'] = make_hours_mappings
              @dest_facility['services'] = map_health_services if @mapping['services']
              @dest_facility['classification'] = map_classification if @mapping['classification']
              @dest_facility['phone'] = make_phone_mappings
              @dest_facility
            end

            def make_direct_mappings
              %w[unique_id name website mobile visn active_status].each_with_object({}) do |name, _attributes|
                @dest_facility[name] = strip(@src_facility['attributes'][@mapping[name]])
              end
            end

            def make_complex_mappings
              %w[access feedback].each_with_object({}) do |name, _attributes|
                @dest_facility[name] = complex_mapping(name)
              end
            end

            def make_phone_mappings
              phone_mapping = complex_mapping('phone')

              phone_mapping.each_key do |phone_type|
                full_phone = phone_mapping[phone_type]
                phone_mapping[phone_type] = remove_blank_extensions(full_phone) if full_phone.present?
              end

              phone_mapping
            end

            def remove_blank_extensions(full_phone_number)
              phone, ext = full_phone_number.split('x')
              if ext.blank?
                phone.strip
              else
                full_phone_number
              end
            end

            def map_classification
              facility = @src_facility['attributes']
              classification_value = @mapping['classification']
              if classification_value.respond_to?(:call)
                classification_value.call(facility)
              else
                strip(facility[classification_value])
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
                'other' => @src_facility['attributes']['Other_Services']
              }
            end

            def calculate_standard_benefits
              cleaned_benefits = clean_benefits(complex_mapping('benefits'))
              cleaned_benefits << 'Pensions' if pensions?
              cleaned_benefits
            end

            def pensions?
              BaseFacility::PENSION_LOCATIONS.include?(@dest_facility['unique_id'])
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
              attrs = @src_facility['attributes']
              item = @mapping[attr_name]

              return {} unless item

              item.transform_values do |value|
                value.respond_to?(:call) ? value.call(attrs) : strip(attrs[value])
              end
            end

            def clean_benefits(benefits_hash)
              benefits_hash.keys.select { |key| benefits_hash[key] == BaseFacility::YES }
            end

            def strip(value)
              value.try(:strip) || value
            end

            def services_date
              id = @dest_facility['unique_id'].upcase
              facility_wait_time = FacilityWaitTime.find(id)

              Date.strptime(facility_wait_time&.source_updated).iso8601 if facility_wait_time&.source_updated.present?
            end

            def collect_health_services
              services = []

              id = @dest_facility['unique_id'].upcase
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
              services << { 'sl1' => ['DentalServices'], 'sl2' => [] } if FacilityDentalService.exists?(facility_id)

              services
            end
          end
        end
      end
    end
  end
end

Faraday::Response.register_middleware facility_parser: Common::Client::Middleware::Response::FacilityParser
