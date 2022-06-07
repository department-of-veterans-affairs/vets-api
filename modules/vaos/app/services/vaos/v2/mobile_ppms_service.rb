# frozen_string_literal: true

require 'common/exceptions'
require 'common/client/errors'

module VAOS
  module V2
    class MobilePPMSService < VAOS::SessionService
      def get_provider(provider_id)
        params = {}
        with_monitoring do
          response = perform(:get, providers_url_with_id(provider_id), params, headers)
          OpenStruct.new(response[:body])
        end
      end

      private

      def providers_url_with_id(id)
        "/ppms/v1/providers/#{id}"
      end
    end
  end
end
