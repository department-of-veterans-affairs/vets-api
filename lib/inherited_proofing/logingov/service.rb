# frozen_string_literal: true

require 'inherited_proofing/logingov/configuration'

module InheritedProofing
  module Logingov
    # This class interacts with Login.gov to create an inherited proofing user.
    class Service < Common::Client::Base
      configuration InheritedProofing::Logingov::Configuration

      SCOPE = 'profile email openid social_security_number'

      # makes an auth call to Login.gov with an inherited_proofing_auth param
      # Login.gov will pass this param back for validation in their user attributes call
      def render_auth(auth_code:)
        renderer = ActionController::Base.renderer
        renderer.controller.prepend_view_path(Rails.root.join('lib', 'inherited_proofing', 'logingov', 'templates'))
        renderer.render(template: 'oauth_get_form',
                        locals: {
                          url: auth_url,
                          params:
                          {
                            acr_values: IAL::LOGIN_GOV_IAL2,
                            client_id: config.client_id,
                            nonce:,
                            prompt: config.prompt,
                            redirect_uri: config.redirect_uri,
                            response_type: config.response_type,
                            scope: SCOPE,
                            state: SecureRandom.hex,
                            inherited_proofing_auth: auth_code
                          }
                        },
                        format: :html)
      end

      private

      def auth_url
        "#{config.base_path}/#{config.auth_path}"
      end

      def nonce
        @nonce ||= SecureRandom.hex
      end
    end
  end
end
