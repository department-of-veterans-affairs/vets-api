# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/monitoring'
require_relative 'configuration'
require_relative 'response'

module Mulesoft
  module PreNeed
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration Mulesoft::PreNeed::Configuration

      def submit_pre_need(payload)
        if mock_enabled?
          Rails.logger.info('[Mulesoft::PreNeed] Mocked response returned')
          return OpenStruct.new(
            status: 200,
            body: {
              message: 'Mocked Mulesoft response',
              submitted: true,
              tx_id: 'MOCK12345'
            }
          )
        end

        response = perform(
          :post,
          '', # already included in base_path
          payload.to_json,
          { 'Content-Type' => 'application/json' }
        )

        Mulesoft::PreNeed::Response.from(response)
      end
    end
  end
end
