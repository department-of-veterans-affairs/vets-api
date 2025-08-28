# frozen_string_literal: true

require 'vets/model'

module FacilitiesApi
  module V2
    module Lighthouse
      class Response
        include Vets::Model

        attribute :body, String
        attribute :current_page, Integer
        attribute :data, Hash, array: true
        attribute :links, Hash
        attribute :meta, Hash
        attribute :per_page, Integer
        attribute :status, Integer
        attribute :total_entries, Integer

        def initialize(body, status)
          super()
          @body = body
          @status = status
          parsed_body = JSON.parse(body)
          @data = Array.wrap(parsed_body['data']) # normalize data to array
          @meta = parsed_body['meta']
          @links = parsed_body['links']
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
          V2::Lighthouse::Facility.new(data.first)
        end

        # services is a string here
        def facility_with_services(services)
          facility = V2::Lighthouse::Facility.new(data.first)
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

          health_services.select { |service| service.new || service.established }
        end

        def build_access_data(health_services)
          if health_services.empty?
            { 'health' => [], 'effectiveDate' => '' }
          else
            { 'health' => health_services, 'effectiveDate' => health_services.first.effectiveDate }
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
