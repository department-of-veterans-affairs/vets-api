# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization
    include Logging

    SERVICE_NAME = 'accredited-representative-portal'
    service_tag SERVICE_NAME

    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user
    around_action :handle_exceptions
    around_action :track_request_execution
    after_action :verify_pundit_authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      track_exception(e, 'api.arp.auth.failure')
      render json: { errors: [e.message] }, status: :forbidden
    end

    private

    def track_request_execution
      event = "api.arp.#{controller_name}.#{action_name}"

      log_info("Starting #{event}", "#{event}.attempt", user_tags)
      yield
      log_info("Completed #{event}", "#{event}.success", user_tags)
    end

    def track_exception(exception, metric, error_class = nil)
      log_error(exception.message, metric, error_class, user_tags)
    end

    def verify_pundit_authorization
      action_name == 'index' ? verify_policy_scoped : verify_authorized
    end

    def handle_exceptions
      yield
    rescue Pundit::NotAuthorizedError => e
      track_exception(e, 'api.arp.auth.failure')
      raise
    rescue Common::Exceptions::Forbidden => e
      track_exception(e, 'api.arp.access.forbidden')
      raise
    rescue => e
      track_exception(e, 'api.arp.error', e.class.name)
      raise
    end

    def verify_pilot_enabled_for_user
      return if Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)

      raise Common::Exceptions::Forbidden, detail: "Feature flag disabled for user #{@current_user.uuid}"
    end
  end
end
