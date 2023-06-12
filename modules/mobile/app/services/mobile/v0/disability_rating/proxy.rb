# frozen_string_literal: true

require 'common/exceptions'

module Mobile
  module V0
    module DisabilityRating
      class Proxy
        def initialize(icn)
          @icn = icn
        end

        def get_rated_disabilities
          auth_params = {
            launch: Base64.encode64(JSON.generate({ patient: @icn }))
          }
          settings = Settings.lighthouse.veteran_verification['form526']

          data = veteran_vertification_service.get_rated_disabilities(
            settings.access_token.client_id,
            settings.access_token.rsa_key,
            { auth_params: }
          )

          data['data']['attributes']
        end

        private

        def veteran_vertification_service
          VeteranVerification::Service.new
        end
      end
    end
  end
end
