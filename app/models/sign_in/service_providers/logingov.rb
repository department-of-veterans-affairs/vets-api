module SignIn
  module ServiceProviders
    class Logingov < Base
      def authorize_params(auth_params)
        # Log incoming parameters
        Rails.logger.info("[Logingov] Incoming auth_params: #{auth_params.inspect}")
        
        # Get base params from parent
        params = super
        Rails.logger.info("[Logingov] Base params from super: #{params.inspect}")

        # Set explicit scope
        scope = 'openid profile email'
        Rails.logger.info("[Logingov] Using scope: #{scope}")

        # Build final params
        final_params = {
          client_id: params[:client_id],
          redirect_uri: params[:redirect_uri],
          response_type: 'code',
          scope: scope,
          state: params[:state],
          nonce: params[:nonce],
          prompt: 'select_account',
          acr_values: Settings.logingov.acr_values || 'http://idmanagement.gov/ns/assurance/ial/1'
        }

        Rails.logger.info("[Logingov] Final authorize params: #{final_params.inspect}")
        final_params
      end

      private

      def client_options
        {
          identifier: client_id,
          secret: client_secret,
          redirect_uri: callback_url,
          scope: 'openid profile email',
          response_type: 'code',
          authorization_endpoint: authorization_endpoint,
          token_endpoint: token_endpoint,
          userinfo_endpoint: userinfo_endpoint
        }
      end

      def default_scope
        'openid profile email'
      end
    end
  end
end 