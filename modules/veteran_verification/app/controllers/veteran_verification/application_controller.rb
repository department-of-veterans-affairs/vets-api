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

    def set_default_format_to_json
      request.format = :json if params[:format].nil? && request.headers['HTTP_ACCEPT'].nil?
    end

    def fetch_aud
      Settings.oidc.isolated_audience.veteran_verification
    end
  end
end
