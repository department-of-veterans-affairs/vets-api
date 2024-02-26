# frozen_string_literal: true

module AccreditedRepresentatives
  # We are duplicating some functionality from `::ApplicationController`
  # because inheriting from it would import inappropriate functionality, around
  # authentication for instance. Maybe we can find a refactor that gives us
  # better reuse. For now, we can place the duplicative code here to help us
  # deal with things later.
  class DuplicativeGlobalApplicationController < ActionController::API
    include ActionController::RequestForgeryProtection
    include ExceptionHandling
    include Headers
    include Pundit::Authorization
    include SentryControllerLogging
    include SentryLogging
    include Traceable

    protect_from_forgery with: :exception, if: -> { ActionController::Base.allow_forgery_protection }
    after_action :set_csrf_header, if: -> { ActionController::Base.allow_forgery_protection }

    def routing_error
      raise Common::Exceptions::RoutingError, params[:path]
    end

    private

    def set_csrf_header
      token = form_authenticity_token
      response.set_header('X-CSRF-Token', token)
      Rails.logger.info('CSRF response token', csrf_token: token)
    end

    # Duplicates `Instrumentation` because it was including
    # `SignIn::Authentication`, which we don't want.
    def append_info_to_payload(payload)
      if @access_token.present?
        payload[:session] = @access_token.session_handle
      elsif session && session[:token]
        payload[:session] = Session.obscure_token(session[:token])
      end
      payload[:user_uuid] = current_user.uuid if current_user.present?
    end
  end
end
