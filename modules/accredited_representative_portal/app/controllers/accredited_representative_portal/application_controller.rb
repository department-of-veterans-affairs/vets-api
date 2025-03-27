# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      log_auth_failure(e)

      render(
        json: { errors: [e.message] },
        status: :forbidden
      )
    end

    rescue_from ActionController::BadRequest do |e|
      render json: { errors: [e.message] }, status: :bad_request
    end

    service_tag 'accredited-representative-portal' # ARP DataDog monitoring: https://bit.ly/arp-datadog-monitoring

    validates_access_token_audience IdentitySettings.sign_in.arp_client_id

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
      log_unexpected_error(e)
      raise e
    end

    def verify_pilot_enabled_for_user
      return if Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)

      message = <<~MSG.squish
        The accredited_representative_portal_pilot feature flag is disabled
        for user with uuid: #{@current_user.uuid}
      MSG

      raise Common::Exceptions::Forbidden, detail: message
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
