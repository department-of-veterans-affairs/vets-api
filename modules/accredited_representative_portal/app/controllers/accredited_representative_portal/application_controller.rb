# frozen_string_literal: true

module AccreditedRepresentativePortal
  class ApplicationController < SignIn::ApplicationController
    include SignIn::AudienceValidator
    include Authenticable
    include Pundit::Authorization
    include ControllerTracking

    service_tag Monitoring::Service::NAME

    validates_access_token_audience Settings.sign_in.arp_client_id

    before_action :verify_pilot_enabled_for_user
    around_action :handle_exceptions
    after_action :verify_pundit_authorization

    rescue_from Pundit::NotAuthorizedError do |e|
      track_error(message: e.message, error: e, tags: [Monitoring::Tag::Error::FORBIDDEN])
      render json: { errors: [e.message] }, status: :forbidden
    end

    private

    def track_exception(exception, _tags = [])
      track_error(message: exception.message, error: exception)
    end

    def verify_pundit_authorization
      action_name == 'index' ? verify_policy_scoped : verify_authorized
    end

    def handle_exceptions
      yield
    rescue => e
      track_error(message: e.message, error: e)
      raise
    end

    def verify_pilot_enabled_for_user
      return if Flipper.enabled?(:accredited_representative_portal_pilot, @current_user)

      raise Common::Exceptions::Forbidden, detail: "Feature flag disabled for user #{@current_user.uuid}"
    end
  end
end
