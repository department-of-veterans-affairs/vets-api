# frozen_string_literal: true

require_relative 'veteran_representative_service/create_veteran_representative_request'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def endpoint
      'VDC/VeteranRepresentativeService'
    end

    def namespaces
      {
        'data' => '/data'
      }
    end
  end
end
