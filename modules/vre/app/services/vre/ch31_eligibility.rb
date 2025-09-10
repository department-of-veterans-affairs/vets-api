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

    def get_details
      send_to_res(payload: { icn: @icn })
    end

    private

    def api_path
      'chapter31-eligibility-details-search'
    end
  end
end
