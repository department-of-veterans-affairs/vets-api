# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      log_auth_failure(e)

      # Return 404 instead of 403 when user has qualifying VSOs but can't access a specific record.
      # This implements the policy that 403s should only occur when the user has no VSOs that
      # accept digital POAs, while all other access control should manifest as 404s or absences.
      #
      if current_user.power_of_attorney_holders.any?(&:accepts_digital_power_of_attorney_requests?)
        render json: { errors: [{ status: 404, detail: 'Not found' }] }, status: :not_found
      else
        render json: { errors: [e.message] }, status: :forbidden
      end
    end

    service_tag 'accredited-representative-portal' # ARP Datadog monitoring
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
