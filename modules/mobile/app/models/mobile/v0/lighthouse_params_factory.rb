# frozen_string_literal: true

module Mobile
  module V0
    # Initialized with a veteran's ICN builds the params needed when posting a request to the
    # Lighthouse access token endpoint.
    #
    class LighthouseParamsFactory
      # @param icn String a veteran's ICN
      #
      def initialize(icn)
        @icn = icn
      end

      # Builds a form encoded parameter set that includes the assertion token, scopes, and
      # veteran or 'patient' ICN.
      #
      # @return String the form encoded set of params
      #
      def build
        hash = {
          grant_type: 'client_credentials',
          client_assertion_type: 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer',
          client_assertion: token,
          scope: scopes,
          launch: launch
        }

        URI.encode_www_form(hash)
      end

      private

      def token
        LighthouseAssertion.new.token
      end

      def scopes
        Settings.lighthouse_health_immunization.scopes.join(' ')
      end

      def launch
        Base64.encode64({ patient: @icn }.to_json)
      end
    end
  end
end
