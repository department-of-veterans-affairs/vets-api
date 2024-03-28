# frozen_string_literal: true

require_relative 'manage_representative_service/read_poa_request'

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def endpoint
      'VDC/ManageRepresentativeService'
    end

    def namespaces
      {
        'data' => 'http://gov.va.vba.benefits.vdc/data'
      }
    end
  end
end
