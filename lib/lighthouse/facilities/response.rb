# frozen_string_literal: true

require 'common/models/base'

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
    end
  end
end
