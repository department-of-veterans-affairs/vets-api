# frozen_string_literal: true

module VRE
  class Ch31Eligibility < VRE::Service
    configuration VRE::Configuration

    STATSD_KEY_PREFIX = 'api.res.eligibility'

    def initialize(icn)
      super()
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      @icn = icn
    end

    # Requests current user's Ch31 eligibility status and details 
    #
    # @return [Hash]
    #
    def get_details
      raw_response = send_to_res(payload: { icn: @icn })
      VRE::Ch31EligibilityResponse.new(raw_response.status, raw_response)
    end

    private

    def api_path
      'chapter31-eligibility-details-search'
    end
  end
end
