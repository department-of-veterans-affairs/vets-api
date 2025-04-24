# frozen_string_literal: true

module V0
  module VirtualAgent
    class JwtToken < Common::Client::Base
      def new_jwt_token(user)
        url = '/users/v2/session?processRules=true'
        # get the basic unsigned JWT token
        token = VAOS::JwtWrapper.new(user).token
        # request a signed JWT token
        response = perform(:post, url, token, headers)
        # raise Common::Exceptions::BackendServiceException.new('VAOS_502', source: self.class) unless body?(response)

        Rails.logger.info('Chatbot JWT session created',
                          { account_uuid: user.account_uuid, jti: decoded_token(token)['jti'] })
        response.body
      end

      def config
        VAOS::Configuration.instance
      end

      private

      def headers
        { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
      end

      def decoded_token(token)
        JWT.decode(token, nil, false).first
      end

      def body?(response)
        response&.body&.present?
      end

      def referrer
        if Settings.hostname.ends_with?('.gov')
          "https://#{Settings.hostname}".gsub('vets', 'va')
        else
          'https://review-instance.va.gov' # VAMF rejects Referer that is not valid; such as those of review instances
        end
      end
    end
  end
end
