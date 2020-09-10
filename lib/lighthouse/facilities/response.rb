# frozen_string_literal: true

require 'common/models/base'
require_relative 'facility'

module Lighthouse
  module Facilities
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
        if meta
          self.current_page = meta['pagination']['current_page']
          self.per_page = meta['pagination']['per_page']
          self.total_entries = meta['pagination']['total_entries']
        end
      end

      def facilities
        facilities = data.each_with_index.map do |facility, index|
          fac = Lighthouse::Facilities::Facility.new(facility)
          fac.distance = meta['distances'][index]['distance'] unless meta['distances'].empty?
          fac
        end

        WillPaginate::Collection.create(current_page, per_page) do |pager|
          pager.replace(facilities)
          pager.total_entries = total_entries
        end
      end

      def facility
        Lighthouse::Facilities::Facility.new(data)
      end
    end
  end
end
