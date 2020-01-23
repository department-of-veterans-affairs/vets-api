# frozen_string_literal: true

require_relative '../vaos/concerns/headers'

module VAOS
  class CCSupportedSitesService < Common::Client::Base
    include Common::Client::Monitoring
    include SentryLogging
    include VAOS::Headers

    configuration VAOS::Configuration

    STATSD_KEY_PREFIX = 'api.vaos'

    attr_reader :user

    def initialize(user)
      @user = user
    end

    def get_supported_sites(site_codes)
      with_monitoring do
        response = perform(:get, url(site_codes), nil, headers(user))
        {
          data: deserialize(response.body),
          meta: {}
        }
      end
    end

    private

    def deserialize(json_hash)
      json_hash[:sites_supporting_var].map do |request|
        OpenStruct.new(request)
      end
    rescue => e
      log_message_to_sentry(e.message, :warn, invalid_json: json_hash)
      []
    end

    def url(site_codes)
      site_codes = Array.wrap(site_codes)
      params = site_codes.reject(&:blank?).empty? ? '' : "?siteCodes=#{site_codes.join(',')}"
      "/var/VeteranAppointmentRequestService/v4/rest/facility-service/supported-facilities#{params}"
    end
  end
end
