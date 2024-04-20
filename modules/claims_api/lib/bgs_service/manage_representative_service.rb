# frozen_string_literal: true

require_relative 'manage_representative_service/read_poa_request'
require_relative 'manage_representative_service/update_poa_request'

module ClaimsApi
  module ManageRepresentativeService
    class << self
      def make_request(**args)
        LocalBGS.new.make_request(
          endpoint: 'VDC/ManageRepresentativeService',
          namespaces: { 'data' => '/data' },
          transform_response: false,
          **args
        )
      end
    end
  end
end
