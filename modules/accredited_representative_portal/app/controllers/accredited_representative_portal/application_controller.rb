# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      # Platform skips Sentry for these
      log_auth_failure(e)
      mapped_error = map_exception(e)
      render_errors(mapped_error)
    end

    service_tag 'accredited-representative-portal' # ARP DataDog monitoring: https://bit.ly/arp-datadog-monitoring

    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user
    around_action :handle_exceptions
    after_action :verify_pundit_authorization

    private

    def verify_pundit_authorization
      action_name == 'index' ? verify_policy_scoped : verify_authorized
    end

    def handle_exceptions
      yield
    rescue => e
      mapped_error = map_exception(e)

      unless skip_sentry_exception?(e)
        log_exception_to_sentry(mapped_error)
      end

      if(e.is_a?(Pundit::NotAuthorizedError))
        log_auth_failure(e)
      end
      
      log_unexpected_error(mapped_error)
      render_errors(mapped_error)
    end

    def skip_sentry_exception?(exception)
      # Inherit platform's skip logic
      return true if exception.class.in?(SKIP_SENTRY_EXCEPTION_TYPES)
      exception.respond_to?(:sentry_type) && !exception.log_to_sentry?
    end

    def verify_pilot_enabled_for_user
      return if Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)

      message = <<~MSG.squish
        The accredited_representative_portal_pilot feature flag is disabled
        for user with uuid: #{@current_user.uuid}
      MSG

      raise Common::Exceptions::Forbidden, detail: message
    end

    def map_exception(exception)
      case exception
      when Breakers::OutageException
        Common::Exceptions::ServiceOutage.new
      when JsonSchema::JsonApiMissingAttribute
        Common::Exceptions::ValidationErrors.new(detail: exception.message)
      when Pundit::NotAuthorizedError
        Common::Exceptions::Forbidden.new(detail: 'User does not have access to the requested resource')
      when Common::Exceptions::BaseError
        # Pass through any Common::Exceptions we've already mapped
        exception
      when ActionController::ParameterMissing
        Common::Exceptions::ParameterMissing.new(exception.param)
      when Common::Client::Errors::ClientError
        Common::Exceptions::ServiceOutage.new(nil, detail: 'Backend Service Outage')
      else
        # Default to internal server error for unmapped exceptions
        Common::Exceptions::InternalServerError.new(exception)
      end
    end

    def log_auth_failure(exception)
      user_uuid = @current_user&.uuid || 'unknown'
      request_path = request&.path || 'unknown_path'

      Rails.logger.warn(
        "ARP: Authorization failure for user=#{user_uuid}, " \
        "path=#{request_path} - #{exception.message}"
      )
    end

    def log_unexpected_error(exception)
      user_uuid = @current_user&.uuid || 'unknown'
      request_path = request&.path || 'unknown_path'

      Rails.logger.error(
        "ARP: Unexpected error occurred for user with user_uuid=#{user_uuid}, " \
        "path=#{request_path} - #{exception.message}"
      )
    end
  end
end
