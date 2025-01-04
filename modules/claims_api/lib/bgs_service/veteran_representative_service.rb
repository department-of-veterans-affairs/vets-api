# frozen_string_literal: true

require_relative 'veteran_representative_service/create_veteran_representative_request'
require_relative 'veteran_representative_service/read_all_veteran_representatives'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    def bean_name
      'VDC/VeteranRepresentativeService'
    end

    private

    def make_request(namespace:, **args)
      super(
        endpoint: 'VDC/VeteranRepresentativeService',
        namespaces: { namespace => '/data' },
        transform_response: false,
        **args
      )
    end
  end
end
