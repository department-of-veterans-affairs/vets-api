# frozen_string_literal: true

require 'common/client/concerns/service_status'
require 'common/models/base'

module Search
  class ResultsResponse < Common::Base
    include Common::Client::ServiceStatus

    attribute :status, Integer
    attribute :body, Hash

    def initialize(status, attributes = nil)
      super(attributes) if attributes
      self.status = status
    end

    def self.from(response)
      body = response.body.merge('pagination' => pagination_object(response.body))
      new(response.status, body: body)
    end

    def cache?
      status == 200
    end

    def metadata
      { status: response_status }
    end

    def response_status
      case status
      when 200
        RESPONSE_STATUS[:ok]
      when 403
        RESPONSE_STATUS[:not_authorized]
      when 404
        RESPONSE_STATUS[:not_found]
      else
        RESPONSE_STATUS[:server_error]
      end
    end

    def self.pagination_object(body)
      {
        'next' => next_offset(body),
        'previous' => previous_offset(body)
      }
    end

    def self.next_offset(raw)
      raw.dig('web', 'next_offset')
    end

    def self.previous_offset(raw)
      # Default size for offset is 20 per page. Can go up to 50.
      offset_limit = 20
      next_offset = next_offset(raw)
      total = raw.dig('web', 'total')

      # If next_offset is blank we're at the last page of results
      if next_offset.blank?
        # Find the remainder of results in the set
        remainder = total % offset_limit
        # Return the second to last offset in the set
        return total - (remainder + offset_limit)
      end

      # The previous_offset of the current results set is equal to the
      # offset_limit (default 20), times 2, subtracted from the next offset
      offset = next_offset - (2 * offset_limit)

      return offset if offset.positive?
      nil
    end
  end
end
