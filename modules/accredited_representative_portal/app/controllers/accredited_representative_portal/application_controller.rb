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

    before_action :track_unique_session
    around_action :handle_exceptions
    after_action :verify_pundit_authorization

    private

    def deny_access_unless_form_enabled(form_id)
      form_class = SavedClaim::BenefitsIntake.form_class_from_proper_form_id(form_id)
      routing_error if form_class&.const_defined?(:FEATURE_FLAG) &&
                       !Flipper.enabled?(form_class::FEATURE_FLAG, @current_user)
    end

    def routing_error
      raise Common::Exceptions::RoutingError, params[:path]
    end

    def track_unique_session
      if @current_user.present?
        arp_session_key = :arp_session_started_for_user

        if request.session[arp_session_key] != @current_user&.uuid
          AccreditedRepresentativePortal::Monitoring.new.track_count('ar.unique_session.count')
          request.session[arp_session_key] = @current_user&.uuid
        end
      end

      true
    end

    def verify_pundit_authorization
      action_name == 'index' ? verify_policy_scoped : verify_authorized
    end

    def handle_exceptions
      yield
    rescue => e
      log_unexpected_error(e)
      raise e
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
