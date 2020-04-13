# frozen_string_literal: true

module VAOS
  class CCEligibilityService < VAOS::BaseService
    def get_eligibility(service_type)
      with_monitoring do
        response = perform(:get, url(service_type), nil, headers)
        {
          data: OpenStruct.new(response.body),
          meta: {}
        }
      end
    end

    private

    def url(service_type)
      "/cce/v1/patients/#{user.icn}/eligibility/#{service_type}"
    end
  end
end
