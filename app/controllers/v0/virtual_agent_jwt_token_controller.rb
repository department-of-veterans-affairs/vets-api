# frozen_string_literal: true

module V0
  class VirtualAgentJwtTokenController < SignIn::ServiceAccountApplicationController
    service_tag 'virtual-agent'
    rescue_from 'V0::VirtualAgentJwtTokenController::ServiceException', with: :service_exception_handler
    rescue_from Net::HTTPError, with: :service_exception_handler

    def create
      jwt_token = VirtualAgent::JwtToken.new(icn).new_jwt_token
      render json: { token: jwt_token }
    end

    private

    def icn
      @service_account_access_token.user_attributes['icn']
    end
  end
end
