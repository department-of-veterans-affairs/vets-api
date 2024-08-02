# frozen_string_literal: true

require 'common/models/base'

module FacilitiesApi
  module V2
    module Lighthouse
      class Response < Common::Base
        attribute :body, String
        attribute :current_page, Integer
        attribute :data, Object
        attribute :links, Object
        attribute :meta, Object
        attribute :per_page, Integer
        attribute :status, Integer
        attribute :total_entries, Integer

        def initialize(body, status)
          super()
          self.body = body
          self.status = status
          parsed_body = JSON.parse(body)
          self.data = parsed_body.key?('data') ? parsed_body['data'] : []
          self.meta = parsed_body['meta']
          self.links = parsed_body['links']
          set_metadata(meta) if meta
        end

        def facilities
          facilities = data.each_with_index.map do |facility, index|
            fac = V2::Lighthouse::Facility.new(facility)
            fac.distance = meta['distances'][index]['distance'] if meta['distances']
            fac
          end

          paginate_response(facilities)
        end

        def facility
          V2::Lighthouse::Facility.new(data)
        end

        # services is a string here
        def facility_with_services(services)
          facility = V2::Lighthouse::Facility.new(data)
          parsed_services = parse_services(services)
          health_services = extract_health_services(parsed_services)
          facility.access = build_access_data(health_services)
          facility
        end

        private

        def parse_services(services)
          JSON.parse(services).fetch('data', [])
        end

        def extract_health_services(services_data)
          health_services = services_data.map do |service|
            V2::Lighthouse::Service.new(service)
          end

          health_services.select { |service| service['new'] || service['established'] }
        end

        def build_access_data(health_services)
          if health_services.empty?
            { 'health' => [], 'effectiveDate' => '' }
          else
            { 'health' => health_services, 'effectiveDate' => health_services.first['effectiveDate'] }
          end
        end

        def set_metadata(meta)
          self.current_page = meta['pagination']['currentPage']
          self.per_page = meta['pagination']['perPage']
          self.total_entries = meta['pagination']['totalEntries']
        end

        def paginate_response(facilities)
          WillPaginate::Collection.create(current_page, per_page) do |pager|
            pager.replace(facilities)
            pager.total_entries = total_entries
          end
        end
      end
    end
  end
end
