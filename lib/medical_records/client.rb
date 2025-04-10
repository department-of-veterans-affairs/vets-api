# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_fhir_session_client'
require 'medical_records/client_session'
require 'medical_records/configuration'
require 'medical_records/patient_not_found'

module MedicalRecords
  ##
  # Core class responsible for Medical Records API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MhvFhirSessionClient

    # Default number of records to request per call when searching
    DEFAULT_COUNT = 9999

    # LOINC codes for clinical notes
    PHYSICIAN_PROCEDURE_NOTE = '11506-3' # Physician procedure note
    DISCHARGE_SUMMARY = '18842-5' # Discharge summary
    CONSULT_RESULT = '11488-4' # Consultation note

    # LOINC codes for vitals
    BLOOD_PRESSURE = '85354-9' # Blood Pressure
    BREATHING_RATE = '9279-1' # Breathing Rate
    HEART_RATE = '8867-4' # Heart Rate
    HEIGHT = '8302-2' # Height
    TEMPERATURE = '8310-5' # Temperature
    WEIGHT = '29463-7' # Weight
    PULSE_OXIMETRY = '59408-5,2708-6, ' # Oxygen saturation in Arterial blood

    # LOINC codes for labs & tests
    MICROBIOLOGY = '79381-0' # Gastrointestinal pathogens panel
    PATHOLOGY = '60567-5' # Comprehensive pathology report panel
    EKG = '11524-6' # EKG Study
    RADIOLOGY = '18748-4' # Diagnostic imaging study

    configuration MedicalRecords::Configuration
    client_session MedicalRecords::ClientSession

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        "#{Settings.mhv.api_gateway.hosts.fhir}/v1/fhir/"
      else
        "#{Settings.mhv.medical_records.host}/fhir/"
      end
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
      @fhir_client ||= sessionless_fhir_client(jwt_bearer_token)
    end

    def get_patient_by_identifier(fhir_client, identifier)
      default_headers = { 'Cache-Control' => 'no-cache' }
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        default_headers = default_headers.merge('x-api-key' => Settings.mhv.medical_records.x_api_key)
      end

      result = fhir_client.search(FHIR::Patient, {
                                    search: { parameters: { identifier: } },
                                    headers: default_headers
                                  })

      # MHV will return a 202 if and only if the patient does not exist. It will not return 202 for
      # multiple patients found.
      return :patient_not_found if result.response[:code] == 202

      resource = result.resource
      handle_api_errors(result) if resource.nil?
      resource
    end

    def list_allergies
      return :patient_not_found unless patient_found?

      bundle = fhir_search(FHIR::AllergyIntolerance,
                           search: { parameters: { patient: patient_fhir_id, 'clinical-status': 'active',
                                                   'verification-status:not': 'entered-in-error' } })
      sort_bundle(bundle, :recordedDate, :desc)
    end

    def get_allergy(allergy_id)
      fhir_read(FHIR::AllergyIntolerance, allergy_id)
    end

    def list_vaccines
      return :patient_not_found unless patient_found?

      bundle = fhir_search(FHIR::Immunization,
                           search: { parameters: { patient: patient_fhir_id, 'status:not': 'entered-in-error' } })
      sort_bundle(bundle, :occurrenceDateTime, :desc)
    end

    def get_vaccine(vaccine_id)
      fhir_read(FHIR::Immunization, vaccine_id)
    end

    # Function args are accepted and ignored for compatibility with MedicalRecords::LighthouseClient
    def list_vitals(*)
      return :patient_not_found unless patient_found?

      # loinc_codes =
      #   "#{BLOOD_PRESSURE},#{BREATHING_RATE},#{HEART_RATE},#{HEIGHT},#{TEMPERATURE},#{WEIGHT},#{PULSE_OXIMETRY}"
      bundle = fhir_search(FHIR::Observation,
                           search: { parameters: { patient: patient_fhir_id, category: 'vital-signs',
                                                   'status:not': 'entered-in-error' } })
      sort_bundle(bundle, :effectiveDateTime, :desc)
    end

    def list_conditions
      return :patient_not_found unless patient_found?

      bundle = fhir_search(FHIR::Condition,
                           search: { parameters: { patient: patient_fhir_id,
                                                   'verification-status:not': 'entered-in-error' } })
      sort_bundle(bundle, :recordedDate, :desc)
    end

    def get_condition(condition_id)
      return :patient_not_found unless patient_found?

      fhir_read(FHIR::Condition, condition_id)
    end

    def list_clinical_notes
      return :patient_not_found unless patient_found?

      bundle = fhir_search(FHIR::DocumentReference,
                           search: { parameters: {
                             patient: patient_fhir_id,
                             category: 'http://hl7.org/fhir/us/core/CodeSystem/us-core-documentreference-category|clinical-note',
                             'status:not': 'entered-in-error'
                           } })

      # Sort the bundle of notes based on the date field appropriate to each note type.
      sort_bundle_with_criteria(bundle, :desc) do |resource|
        loinc_code = if resource.respond_to?(:type) && resource.type.respond_to?(:coding)
                       resource.type.coding&.find do |coding|
                         coding.respond_to?(:system) && coding.system == 'http://loinc.org'
                       end&.code
                     end

        case loinc_code
        when PHYSICIAN_PROCEDURE_NOTE, CONSULT_RESULT
          resource.date
        when DISCHARGE_SUMMARY
          resource.context&.period&.end
        end
      end
    end

    def get_clinical_note(note_id)
      return :patient_not_found unless patient_found?

      fhir_read(FHIR::DocumentReference, note_id)
    end

    def list_labs_and_tests
      return :patient_not_found unless patient_found?

      bundle = fhir_search(FHIR::DiagnosticReport,
                           search: { parameters: { patient: patient_fhir_id, 'status:not': 'entered-in-error' } })
      sort_bundle(bundle, :effectiveDateTime, :desc)
    end

    def get_diagnostic_report(record_id)
      return :patient_not_found unless patient_found?

      fhir_read(FHIR::DiagnosticReport, record_id)
    end

    protected

    ##
    # Fetch EKG and Radiology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_document_reference
      return :patient_not_found unless patient_found?

      loinc_codes = "#{EKG},#{RADIOLOGY}"
      fhir_search(FHIR::DocumentReference,
                  search: { parameters: { patient: patient_fhir_id, type: loinc_codes,
                                          'status:not': 'entered-in-error' } })
    end

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
    # Perform a FHIR search. Returns the first page of results only.
    #
    # @param fhir_model [FHIR::Model] The type of resource to search
    # @param params [Hash] The parameters to pass the search
    # @return [FHIR::ClientReply]
    #
    def fhir_search_query(fhir_model, params)
      default_headers = { 'Cache-Control' => 'no-cache' }
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        default_headers = default_headers.merge('x-api-key' => Settings.mhv.medical_records.x_api_key)
      end

      params[:headers] = default_headers.merge(params.fetch(:headers, {}))

      params[:search][:parameters].merge!(_count: DEFAULT_COUNT)

      result = fhir_client.search(fhir_model, params)
      handle_api_errors(result) if result.resource.nil?
      result
    end

    def fhir_read(fhir_model, id)
      default_headers = {}
      if Flipper.enabled?(:mhv_medical_records_migrate_to_api_gateway)
        default_headers = default_headers.merge('x-api-key' => Settings.mhv.medical_records.x_api_key)
      end

      result = fhir_client.read(fhir_model, id, nil, nil, { headers: default_headers })
      handle_api_errors(result) if result.resource.nil?
      result.resource
    end

    def handle_api_errors(result)
      if result.code.present? && result.code >= 400
        body = JSON.parse(result.body)
        diagnostics = body['issue']&.first&.fetch('diagnostics', nil)
        diagnostics = "Error fetching data#{": #{diagnostics}" if diagnostics}"

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

    ##
    # Sort the FHIR::Bundle entries for lab & test results in reverse chronological order.
    # Different entry types use different date fields for sorting.
    #
    # @param entries a list of FHIR objects
    #
    def sort_lab_entries(entries)
      entries.sort_by! do |entry|
        case entry
        when FHIR::DiagnosticReport
          -entry.effectiveDateTime.to_i
        when FHIR::DocumentReference
          -entry.date.to_i
        else
          0
        end
      end
    end

    private

    def patient_found?
      !patient_fhir_id.nil?
    end
  end
end
