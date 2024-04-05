# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Services
    class FetchPoaRequests
      def initialize(poa_codes)
        @poa_codes = poa_codes
      end

      # TODO: Update the below to call the Dash API to fetch POA requests
      def call
        file_path = 'modules/accredited_representative_portal/spec/fixtures/' \
                    'dash_read_poa_request_response_fixtures.json'
        file_data = File.read(file_path)
        all_records_json = JSON.parse(file_data)
        all_records = all_records_json['poa_request_respond_return_vo_list']

        all_records.select { |record| @poa_codes.include?(record['poa_code']) }
      rescue => e
        Rails.logger.error "Failed to fetch POA requests: #{e.message}"
        []
      end
    end
  end
end
