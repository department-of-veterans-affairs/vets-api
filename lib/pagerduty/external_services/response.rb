# frozen_string_literal: true

require 'vets/model'
require 'pagerduty/response'
require 'pagerduty/models/service'
require_relative 'service'

module PagerDuty
  module ExternalServices
    class Response < PagerDuty::Response
      attribute :reported_at, Vets::Type::ISO8601Time
      attribute :statuses, Hash, array: true # PagerDuty::Models::Service

      validates :reported_at, presence: true

      # @param raw_response [Faraday::Env] Response from PagerDuty `GET /services` call
      # @return [PagerDuty::ExternalServices::Response] An instance of this class
      #
      def self.from(raw_response)
        services = raw_response&.body&.dig('services').presence || []

        new(
          raw_response&.status,
          reported_at: Time.current.iso8601,
          statuses: PagerDuty::Models::Service.statuses_for(services).map(&:attributes)
        )
      end
    end
  end
end
