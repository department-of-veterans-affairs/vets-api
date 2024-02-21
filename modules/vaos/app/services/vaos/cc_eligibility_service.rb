# frozen_string_literal: true

module VAOS
  class CCEligibilityService < VAOS::SessionService
    def get_eligibility(service_type)
      with_monitoring do
        response = perform(:get, url(service_type), nil, headers)

        elig_data = extract_elig_data(response)
        Rails.logger.info('VAOS CCEligibility details', elig_data.to_json) unless elig_data.values.all?(&:nil?)

        {
          data: OpenStruct.new(response.body),
          meta: {}
        }
      end
    end

    private

    def extract_elig_data(response)
      icn = response.body.dig(:patient_request, :patient_icn)
      icn_digest = Digest::SHA256.hexdigest(icn) unless icn.nil?
      {
        icn_digest:,
        service_type: response.body.dig(:patient_request, :service_type),
        eligible: response.body[:eligible],
        eligibility_codes: response.body[:eligibility_codes],
        no_full_service_va_medical_facility: response.body[:no_full_service_va_medical_facility],
        grandfathered: response.body[:grandfathered],
        timestamp: response.body.dig(:patient_request, :timestamp)
      }
    end

    def url(service_type)
      "/cce/v1/patients/#{user.icn}/eligibility/#{service_type}"
    end
  end
end
