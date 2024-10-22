# frozen_string_literal: true

require 'common/client/base'
require 'medical_records/lighthouse_configuration'
# require 'medical_records/patient_not_found'

module MedicalRecords
  ##
  # Core class responsible for Medical Records API interface operations with the Lighthouse FHIR server.
  #
  class LighthouseClient < Common::Client::Base
    # Default number of records to request per call when searching
    DEFAULT_COUNT = 10

    configuration MedicalRecords::LighthouseConfiguration

    ##
    # Initialize the client
    #
    # @param icn [String] MHV patient ICN
    #
    def initialize(icn)
      super()

      # TODO: Remove this temporary ICN once the Lighthouse sandbox test users are available
      icn = '23000219'
      puts "Temp icn for testing with Lighthouse sandbox users: #{icn}"
      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      @icn = icn
    end

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      Settings.mhv.lighthouse.base_url
    end

    ##
    # Create a new FHIR::Client instance, given the provided bearer token. This method does not require a
    # client_session to have been initialized.
    #
    # @param bearer_token [String] The bearer token from the authentication call
    # @return [FHIR::Client]
    #
    def sessionless_fhir_client(bearer_token)
      # FHIR debug level is extremely verbose, printing the full contents of every response body.
      ::FHIR.logger.level = Logger::INFO

      FHIR::Client.new(base_path).tap do |client|
        client.use_r4
        client.default_json
        client.use_minimal_preference
        client.set_bearer_token(bearer_token)
      end
    end

    ##
    # Create a new FHIR::Client instance based on the client_session. Use an existing client if one already exists
    # in this instance.
    #
    # @return [FHIR::Client]
    #
    def fhir_client
      @fhir_client ||= sessionless_fhir_client(self.class.configuration.get_token(@icn))
    end

    # def get_patient_by_identifier(fhir_client, identifier)
    #   result = fhir_client.search(FHIR::Patient, {
    #                                 search: { parameters: { identifier: } },
    #                                 headers: { 'Cache-Control': 'no-cache' }
    #                               })
    #   resource = result.resource
    #   handle_api_errors(result) if resource.nil?
    #   resource
    # end

    def list_allergies
      bundle = fhir_search(FHIR::AllergyIntolerance,
                           {
                             search: { parameters: { patient: @icn, 'clinical-status': 'active' } },
                             headers: { 'Cache-Control': 'no-cache' }
                           })
      sort_bundle(bundle, :recordedDate, :desc)
    end

    def get_allergy(allergy_id)
      fhir_read(FHIR::AllergyIntolerance, allergy_id)
    end

    protected

    ##
    # Perform a FHIR search. This method will continue making queries until all results have been returned.
    #
    # @param fhir_model [FHIR::Model] The type of resource to search
    # @param params [Hash] The parameters to pass the search
    # @return [FHIR::Bundle]
    #
    def fhir_search(fhir_model, params)
      reply = fhir_search_query(fhir_model, params)
      combined_bundle = reply.resource
      loop do
        break unless reply.resource.next_link

        reply = fhir_client.next_page(reply)
        combined_bundle = merge_bundles(combined_bundle, reply.resource)
      end
      combined_bundle
    end

    ##
    # Perform a FHIR search. Returns the first page of results only. Filters out FHIR records
    # that are not active.
    #
    # @param fhir_model [FHIR::Model] The type of resource to search
    # @param params [Hash] The parameters to pass the search
    # @return [FHIR::ClientReply]
    #
    def fhir_search_query(fhir_model, params)
      params[:search][:parameters].merge!(_count: DEFAULT_COUNT)
      result = fhir_client.search(fhir_model, params)
      handle_api_errors(result) if result.resource.nil?
      result
    end

    def fhir_read(fhir_model, id)
      result = fhir_client.read(fhir_model, id)
      handle_api_errors(result) if result.resource.nil?
      result.resource
    end

    def handle_api_errors(result)
      if result.code.present? && result.code >= 400
        body = JSON.parse(result.body)
        diagnostics = body['issue']&.first&.fetch('diagnostics', nil)
        diagnostics = "Error fetching data#{": #{diagnostics}" if diagnostics}"

        # Special-case exception handling
        if result.code == 500 && diagnostics.include?('HAPI-1363')
          # "HAPI-1363: Either No patient or multiple patient found"
          raise MedicalRecords::PatientNotFound
        end

        # Default exception handling
        raise Common::Exceptions::BackendServiceException.new(
          "MEDICALRECORDS_#{result.code}",
          status: result.code,
          detail: diagnostics,
          source: self.class.to_s
        )
      end
    end

    ##
    # Merge two FHIR bundles into one, with an updated total count.
    #
    # @param bundle1 [FHIR:Bundle] The first FHIR bundle
    # @param bundle2 [FHIR:Bundle] The second FHIR bundle
    # @param page_num [FHIR:Bundle]
    #
    def merge_bundles(bundle1, bundle2)
      unless bundle1.resourceType == 'Bundle' && bundle2.resourceType == 'Bundle'
        raise 'Both inputs must be FHIR Bundles'
      end

      # Clone the first bundle to avoid modifying the original
      merged_bundle = bundle1.clone

      # Merge the entries from the second bundle into the merged_bundle
      merged_bundle.entry ||= []
      bundle2.entry&.each do |entry|
        merged_bundle.entry << entry
      end

      # Update the total count in the merged bundle
      merged_bundle.total = merged_bundle.entry.count

      merged_bundle
    end

    ##
    # Apply pagination to the entries in a FHIR::Bundle object. This assumes sorting has already taken place.
    #
    # @param entries a list of FHIR objects
    # @param page_size [Fixnum] page size
    # @param page_num [Fixnum] which page to return
    #
    def paginate_bundle_entries(entries, page_size, page_num)
      start_index = (page_num - 1) * page_size
      end_index = start_index + page_size
      paginated_entries = entries[start_index...end_index]

      # Return the paginated result or an empty array if no entries
      paginated_entries || []
    end

    ##
    # Sort the FHIR::Bundle entries on a given field and sort order. If a field is not present, that entry
    # is sorted to the end.
    #
    # @param bundle [FHIR::Bundle] the bundle to sort
    # @param field [Symbol, String] the field to sort on (supports nested fields with dot notation)
    # @param order [Symbol] the sort order, :asc (default) or :desc
    #
    def sort_bundle(bundle, field, order = :asc)
      field = field.to_s
      sort_bundle_with_criteria(bundle, order) do |resource|
        fetch_nested_value(resource, field)
      end
    end

    ##
    # Sort the FHIR::Bundle entries based on a provided block. The block should handle different resource types
    # and define how to extract the sorting value from each.
    #
    # @param bundle [FHIR::Bundle] the bundle to sort
    # @param order [Symbol] the sort order, :asc (default) or :desc
    #
    def sort_bundle_with_criteria(bundle, order = :asc)
      sorted_entries = bundle.entry.sort do |entry1, entry2|
        value1 = yield(entry1.resource)
        value2 = yield(entry2.resource)
        if value2.nil?
          -1
        elsif value1.nil?
          1
        else
          order == :asc ? value1 <=> value2 : value2 <=> value1
        end
      end
      bundle.entry = sorted_entries
      bundle
    end

    ##
    # Fetches the value of a potentially nested field from a given object.
    #
    # @param object [Object] the object to fetch the value from
    # @param field_path [String] the dot-separated path to the field
    #
    def fetch_nested_value(object, field_path)
      field_path.split('.').reduce(object) do |obj, method|
        obj.respond_to?(method) ? obj.send(method) : nil
      end
    end
  end
end
