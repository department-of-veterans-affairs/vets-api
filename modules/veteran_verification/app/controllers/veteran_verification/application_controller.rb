# frozen_string_literal: true

module VeteranVerification
  class ApplicationController < ::OpenidApplicationController
    # The Veteran Verification Rails Engine used to have a route constraint
    # that made all responses come in as JSON. Because of support for the
    # application/jwt mimetype, that constraint was too limiting. But many
    # of the original routes assumed request headers would also ask for JSON,
    # so we set that default.
    before_action { set_default_format_to_json }

    def authenticate_token
      # Not supported for Client Credentials tokens
      return false if token.blank? || token.client_credentials_token?

      @session = Session.find(Digest::SHA256.hexdigest(token.to_s))
      if @session.nil?
        profile = fetch_okta_profile(token.identifiers.okta_uid)
        establish_session(profile)
      end
      return false if @session.nil? || @session.uuid.nil?

      open_id = get_open_id_user
      @current_user = open_id.find(@session.uuid)
    end

    def get_open_id_user
      if Settings.vet_verification.mock_emis
        MockOpenIdUser
      else
        OpenidUser
      end
    end

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end

    def fetch_aud
      Settings.oidc.isolated_audience.veteran_verification
    end

    def set_tags_and_extra_context
      RequestStore.store['additional_request_attributes'] = { 'source' => 'veteran_verification' }
      Raven.tags_context(source: 'veteran_verification')
    end
  end
end
