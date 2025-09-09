# frozen_string_literal: true

module SignIn
  class ApplicationController < ActionController::API
    include SignIn::Authentication
    include SignIn::Instrumentation
    include Pundit::Authorization
    include ActionController::Cookies
    include ActionController::RequestForgeryProtection
    include ExceptionHandling
    include Headers
    include ControllerLoggingContext
    include SentryLogging
    include SentryControllerLogging
    include Traceable
    service_tag 'identity'

    skip_before_action :authenticate, only: :cors_preflight

    def cors_preflight
      head(:ok)
    end

    private

    attr_reader :current_user

    def set_csrf_header
      response.set_header('X-CSRF-Token', form_authenticity_token)
    end
  end
end
