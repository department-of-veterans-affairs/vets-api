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
        OpenStruct.new(response.body)
      end
    end

    private

    def url(site_codes)
      site_codes = Array.wrap(site_codes)
      params = site_codes.reject(&:blank?).empty? ? '' : "?siteCodes=#{site_codes.join(',')}"
      "/var/VeteranAppointmentRequestService/v4/rest/facility-service/supported-facilities#{params}"
    end
  end
end
