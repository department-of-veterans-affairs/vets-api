# frozen_string_literal: true

require 'common/models/attribute_types/iso8601_time'
require 'pagerduty/response'
require 'pagerduty/models/service'
require_relative 'service'

module PagerDuty
  module ExternalServices
    class Response < PagerDuty::Response
      attribute :reported_at, Common::ISO8601Time
      attribute :statuses, Array[Service]

      validates :reported_at, presence: true

      # @param raw_response [Faraday::Env] Response from PagerDuty `GET /services` call
      # @return [PagerDuty::ExternalServices::Response] An instance of this class
      #
      def self.from(raw_response)
        services = raw_response&.body&.dig('services').presence || []

        new(
          raw_response&.status,
          reported_at: Time.current.iso8601,
          statuses: PagerDuty::Models::Service.statuses_for(services).map(&:to_h)
        )
      end
    end
  end
end
