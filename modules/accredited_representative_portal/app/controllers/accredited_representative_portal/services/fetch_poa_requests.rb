# frozen_string_literal: true

module AccreditedRepresentativePortal
  module Services
    # The FetchPoaRequests service is responsible for retrieving Power of Attorney (POA) request records
    # based on provided Power of Attorney codes. This class currently reads from a JSON file as a temporary
    # source of data. In the future, this service will be updated to fetch POA requests directly from the
    # Lighthouse API once the appropriate endpoint is ready.
    #
    # This service is a part of the interim solution to support development and testing of the Accredited
    # Representative portal. The use of a static JSON file allows for the simulation of interacting with
    # an API and facilitates the frontend development process.
    #
    # Example usage:
    #   fetcher = AccreditedRepresentativePortal::Services::FetchPoaRequests.new(['A1Q', '091'])
    #   result = fetcher.call
    #   puts result # => { 'records': [...], 'meta': { 'totalRecords': '...' } }
    #
    # TODO: This class is slated for update to use the Lighthouse API once the appropriate endpoint
    # is available. For more information on the transition plan, refer to:
    # https://app.zenhub.com/workspaces/accredited-representative-facing-team-65453a97a9cc36069a2ad1d6/issues/gh/department-of-veterans-affairs/va.gov-team/80195
    class FetchPoaRequests
      # Initializes the FetchPoaRequests service with the given POA codes.
      # @param poa_codes [Array<String>] an array of POA codes to filter the POA requests.
      def initialize(poa_codes)
        @poa_codes = poa_codes
      end

      # Fetches POA request records filtered by the initialized POA codes.
      # Currently reads from a static JSON file as a data source.
      # @return [Hash] A hash containing the filtered records and metadata.
      def call
        file_path = Rails.root.join('modules', 'accredited_representative_portal', 'spec', 'fixtures',
                                    'poa_records.json')
        file_data = File.read(file_path)
        all_records_json = JSON.parse(file_data)
        all_records = all_records_json['records']

        filtered_records = all_records.select do |record|
          @poa_codes.include?(record['attributes']['poaCode'])
        end

        { 'records' => filtered_records, 'meta' => { 'totalRecords' => filtered_records.count.to_s } }
      rescue => e
        Rails.logger.error "Failed to fetch POA requests: #{e.message}"
        { 'data' => [], 'meta' => { 'totalRecords' => '0' } }
      end
    end
  end
end
