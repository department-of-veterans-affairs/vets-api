# frozen_string_literal: true

require 'common/models/base'

module FacilitiesApi
  module V1
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
          self.data = parsed_body['data']
          self.meta = parsed_body['meta']
          self.links = parsed_body['links']
          set_metadata(meta) if meta
        end

        def facilities
          facilities = data.each_with_index.map do |facility, index|
            fac = V1::Lighthouse::Facility.new(facility)
            fac.distance = meta['distances'][index]['distance'] unless meta['distances'].empty?
            fac
          end

          paginate_response(facilities)
        end

        def facility
          V1::Lighthouse::Facility.new(data)
        end

        private

        def set_metadata(meta)
          self.current_page = meta['pagination']['current_page']
          self.per_page = meta['pagination']['per_page']
          self.total_entries = meta['pagination']['total_entries']
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
