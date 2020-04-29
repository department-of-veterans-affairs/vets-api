# frozen_string_literal: true

require 'common/models/base'

module Lighthouse
  module Facilities
    class Response < Common::Base
      attribute :body, String
      attribute :current_page, Integer
      attribute :data, Object
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

        self.current_page = meta['pagination']['current_page']
        self.per_page = meta['pagination']['per_page']
        self.total_entries = meta['pagination']['total_entries']
      end

      def facilities
        data.each_with_index.map do |facility, index|
          fac = Lighthouse::Facilities::Facility.new(facility)
          fac.distance = meta['distances'][index]['distance'] unless meta['distances'].empty?
          fac
        end.paginate(
          page: current_page,
          per_page: per_page,
          total: total_entries
        )
      end

      def facility
        Lighthouse::Facilities::Facility.new(data)
      end
    end
  end
end
