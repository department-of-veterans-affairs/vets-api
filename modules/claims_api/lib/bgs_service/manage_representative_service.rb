# frozen_string_literal: true

require_relative 'manage_representative_service/read_poa_request'
require_relative 'manage_representative_service/update_poa_request'

module ClaimsApi
  class ManageRepresentativeService < ClaimsApi::LocalBGS
    def endpoint
      'VDC/ManageRepresentativeService'
    end

    def namespaces
      {
        'data' => '/data'
      }
    end
  end
end
