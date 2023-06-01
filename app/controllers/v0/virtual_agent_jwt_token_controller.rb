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
        jwt_token = VirtualAgent::JwtToken.new.new_jwt_token(current_user)
        render json: { token: jwt_token }
      else
        render json: { token: 'disabled' }
      end
    end
  end
end
