# frozen_string_literal: true

module VAOS
  class CCSupportedSitesService < VAOS::BaseService
    def get_supported_sites(site_codes)
      with_monitoring do
        response = perform(:get, url(site_codes), nil, headers)
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
    end

    def url(site_codes)
      site_codes = Array.wrap(site_codes)
      params = site_codes.reject(&:blank?).empty? ? '' : "?siteCodes=#{site_codes.join(',')}"
      "/var/VeteranAppointmentRequestService/v4/rest/facility-service/supported-facilities#{params}"
    end
  end
end
