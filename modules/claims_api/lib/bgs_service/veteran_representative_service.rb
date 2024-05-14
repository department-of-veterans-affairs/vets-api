# frozen_string_literal: true

require_relative 'veteran_representative_service/create_veteran_representative_request'
require_relative 'veteran_representative_service/read_all_veteran_representatives'

module ClaimsApi
  class VeteranRepresentativeService < ClaimsApi::LocalBGS
    private

    def make_request(namespace:, **args)
      raise ArgumentError, "Namespace argument is missing" if namespace.nil?
      super(
        endpoint: 'VDC/VeteranRepresentativeService',
        namespaces: { namespace => '/data' },
        transform_response: false,
        **args
      )
    end
  end
end
