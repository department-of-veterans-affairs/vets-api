# frozen_string_literal: true

require 'vets/model'
require_relative '../facility'

module Lighthouse
  module Facilities
    module V1
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
          if meta
            @current_page = meta['pagination']['currentPage']
            @per_page = meta['pagination']['perPage']
            @total_entries = meta['pagination']['totalEntries']
          end
        end

        def facilities
          facilities = data.each_with_index.map do |facility, index|
            facility['attributes'] = facility['attributes'].transform_keys(&:underscore)
            fac = Lighthouse::Facilities::Facility.new(facility)
            fac.distance = meta['distances'][index]['distance'] if meta['distances'].present?
            fac
          end

          WillPaginate::Collection.create(current_page, per_page) do |pager|
            pager.replace(facilities)
            pager.total_entries = total_entries
          end
        end

        def facility
          Lighthouse::Facilities::Facility.new(data.first)
        end
      end
    end
  end
end
