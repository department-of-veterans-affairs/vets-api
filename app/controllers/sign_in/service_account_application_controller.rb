# frozen_string_literal: true

module SignIn
  class ServiceAccountApplicationController < ActionController::API
    include SignIn::Authentication
    include SignIn::ServiceAccountAuthentication
    include Pundit::Authorization
    include ExceptionHandling
    include Headers
    include ControllerLoggingContext
    include SentryLogging
    include SentryControllerLogging
    include Traceable

    before_action :authenticate_service_account
    skip_before_action :authenticate

    private

    attr_reader :current_user
  end
end
