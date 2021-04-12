# frozen_string_literal: true

module VeteranVerification
  class ApplicationController < ::OpenidApplicationController
    skip_before_action :set_tags_and_extra_content, raise: false

    # The Veteran Verification Rails Engine used to have a route constraint
    # that made all responses come in as JSON. Because of support for the
    # application/jwt mimetype, that constraint was too limiting. But many
    # of the original routes assumed request headers would also ask for JSON,
    # so we set that default.
    before_action { set_default_format_to_json }

    def authenticate_token
      return false if token.blank? || token.client_credentials_token? # Not supported for Client Credentials tokens
      @session = Session.find(token)
      if @session.nil?
        profile = fetch_profile(token.identifiers.okta_uid)
        establish_session(profile)
      end
      return false if @session.nil?

      open_id = OpenidUser
      open_id = MockOpenIdUser if Settings.vet_verification.mock_emis
      @current_user = open_id.find(@session.uuid)
    end

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end

    def fetch_aud
      Settings.oidc.isolated_audience.veteran_verification
    end
  end
end
