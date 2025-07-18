# frozen_string_literal: true

require 'vets/shared_logging'

module SignIn
  class ServiceAccountApplicationController < ActionController::API
    include SignIn::Authentication
    include SignIn::ServiceAccountAuthentication
    include Pundit::Authorization
    include ExceptionHandling
    include Headers
    include ControllerLoggingContext
    include Vets::SharedLogging
    include SentryControllerLogging
    include Traceable

    before_action :authenticate_service_account
    skip_before_action :authenticate

    private

    attr_reader :current_user
  end
end
