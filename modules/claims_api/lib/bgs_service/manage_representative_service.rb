# frozen_string_literal: true

require_relative 'manage_representative_service/update_poa_request'

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    private

    def make_request(**args)
      super(
        endpoint: 'VDC/ManageRepresentativeService',
        namespaces: { 'data' => '/data' },
        transform_response: false,
        **args
      )
    end
  end
end
