# frozen_string_literal: true

require 'feature_flipper'
require 'aes_256_cbc_encryptor'

module DecisionReviews
  class ApplicationController < ActionController::API
    include AuthenticationAndSSOConcerns
    include ActionController::RequestForgeryProtection
    include ExceptionHandling
    include Headers
    include Pundit::Authorization
    include Traceable
    include ControllerLoggingContext

    protect_from_forgery with: :exception, if: -> { ActionController::Base.allow_forgery_protection }
    after_action :set_csrf_header, if: -> { ActionController::Base.allow_forgery_protection }

    private

    attr_reader :current_user

    def set_csrf_header
      token = form_authenticity_token
      response.set_header('X-CSRF-Token', token)
    end
  end
end
