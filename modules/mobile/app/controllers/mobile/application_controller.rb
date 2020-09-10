# frozen_string_literal: true

module Mobile
  class ApplicationController < BaseApplicationController
    before_action :check_feature_flag, :authenticate

    TOKEN_REGEX = /Bearer /.freeze

    private
    
    def check_feature_flag
      return nil if Flipper.enabled?(:mobile_api)

      message = {
        errors: [
          {
            title: 'Not found',
            detail: 'There are no routes matching your request',
            code: '411',
            status: '404'
          }
        ]
      }

      render json: message, status: :not_found
    end
    
    def authenticate
      raise Common::Exceptions::Forbidden.new(detail: 'Missing bearer auth token') if auth_token.nil?
      
      
    end
    
    def auth_token
      auth_header = request.authorization.to_s
      auth_header[TOKEN_REGEX]
    end
  end
end
