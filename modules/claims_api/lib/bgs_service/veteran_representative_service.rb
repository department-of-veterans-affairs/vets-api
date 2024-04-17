# frozen_string_literal: true

require_relative 'veteran_representative_service/read_all_veteran_representatives'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def endpoint
      'VDC/VeteranRepresentativeService'
    end

    def namespaces
      {
        'ns0' => '/data'
      }
    end
  end
end
