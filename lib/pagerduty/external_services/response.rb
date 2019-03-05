# frozen_string_literal: true

require 'common/models/attribute_types/iso8601_time'

module PagerDuty
  module ExternalServices
    class Response < PagerDuty::Response
      attribute :reported_at, Common::ISO8601Time
      attribute :statuses, Array[Service]

      validates :reported_at, presence: true

      def self.from(raw_response = nil)
        services = raw_response&.body&.dig('services').presence || []

        new(
          raw_response&.status,
          reported_at: Time.current.iso8601,
          statuses: PagerDuty::Models::Service.statuses_for(services)
        )
      end
    end
  end
end
