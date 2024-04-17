# frozen_string_literal: true

require_relative 'veteran_representative_service/read_all_veteran_representatives'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    private

    def make_request(**args)
      super(
        endpoint: 'VDC/VeteranRepresentativeService',
        namespaces: { 'ns0' => '/data' },
        transform_response: false,
        **args
      )
    end
  end
end
