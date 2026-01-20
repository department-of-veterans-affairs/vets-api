# frozen_string_literal: true

module SignIn
  class ApplicationController < ActionController::API
    include SignIn::Authentication
    include SignIn::Instrumentation
    include Pundit::Authorization
    include ActionController::Cookies
    include ExceptionHandling
    include Headers
    include ControllerLoggingContext
    include SentryControllerLogging
    include Traceable
    service_tag 'identity'

    skip_before_action :authenticate, only: :cors_preflight

    around_action :tag_with_controller_name

    def cors_preflight
      head(:ok)
    end

    private

    attr_reader :current_user
  end
end
