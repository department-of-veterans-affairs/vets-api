# frozen_string_literal: true

require 'common/client/base'
require 'lighthouse/veterans_health/client'

module MedicalRecords
  ##
  # Core class responsible for Medical Records API interface operations with the Lighthouse FHIR server.
  #
  class LighthouseClient < Common::Client::Base
    ##
    # Initialize the client
    #
    # @param icn [String] MHV patient ICN
    #
    def initialize(icn)
      super()

      raise Common::Exceptions::ParameterMissing, 'ICN' if icn.blank?

      @icn = icn

      @client = Lighthouse::VeteransHealth::Client.new(@icn)
    end

    def authenticate
      # FIXME: Explore doing this in a less janky way.
      # This is called by the MHV Controller Concern, but is not needed for this client
      # because it is handled in Lighthouse::VeteransHealth::Client::retrieve_bearer_token
    end

    def list_allergies
      bundle = @client.list_allergy_intolerances
      bundle = Oj.load(bundle[:body].to_json, symbol_keys: true)
      sort_bundle(bundle, :recordedDate, :desc)
    end

    def get_allergy(allergy_id)
      bundle = @client.get_allergy_intolerance(allergy_id)
      Oj.load(bundle[:body].to_json, symbol_keys: true)
    end

    protected

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
      sorted_entries = bundle[:entry].sort do |entry1, entry2|
        value1 = yield(entry1[:resource])
        value2 = yield(entry2[:resource])
        if value2.nil?
          -1
        elsif value1.nil?
          1
        else
          order == :asc ? value1 <=> value2 : value2 <=> value1
        end
      end
      bundle[:entry] = sorted_entries
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

    def measure_duration(event: 'default', tags: [])
      # Use time since boot to avoid clock skew issues
      # https://github.com/sidekiq/sidekiq/issues/3999
      start_time = ::Process.clock_gettime(::Process::CLOCK_MONOTONIC)
      result = yield
      duration = (::Process.clock_gettime(::Process::CLOCK_MONOTONIC) - start_time).round(4)

      StatsD.measure("api.mhv.lighthouse.#{event}.duration", duration, tags:)
      result
    end
  end
end
