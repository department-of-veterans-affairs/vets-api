# frozen_string_literal: true

require 'erb'

module V0
  class VirtualAgentJwtTokenController < ApplicationController
    rescue_from 'V0::VirtualAgentJwtTokenController::ServiceException', with: :service_exception_handler
    rescue_from Net::HTTPError, with: :service_exception_handler

    def create
      # on a post request, if the flipper is enabled
      if Flipper.enabled?(:virtual_agent_fetch_jwt_token, current_user)
        # create a new jwt token
        jwt_token = new_jwt_token(current_user)
        render json: { token: jwt_token }
      else
        render json: { token: 'disabled' }
      end
    end

    private

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

    def headers
      { 'Accept' => 'text/plain', 'Content-Type' => 'text/plain', 'Referer' => referrer }
    end

    def decoded_token(token)
      JWT.decode(token, nil, false).first
    end

    def body?(response)
      response&.body && response.body.present?
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
