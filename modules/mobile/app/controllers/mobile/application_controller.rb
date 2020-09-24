# frozen_string_literal: true

module Mobile
  class ApplicationController < ActionController::API
    before_action :check_feature_flag

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
  end
end
