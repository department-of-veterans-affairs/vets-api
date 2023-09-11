# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_jwt_session_client'
require 'medical_records/client_session'
require 'medical_records/configuration'

module MedicalRecords
  ##
  # Core class responsible for Medical Records API interface operations
  #
  class Client < Common::Client::Base
    include Common::Client::Concerns::MHVJwtSessionClient

    # Default number of records to request per call when searching
    DEFAULT_COUNT = 9999

    # LOINC codes for clinical notes
    PHYSICIAN_PROCEDURE_NOTE = '11505-5' # Physician procedure note
    DISCHARGE_SUMMARY = '18842-5' # Discharge summary

    # LOINC codes for vitals
    BLOOD_PRESSURE = '85354-9' # Blood Pressure
    BREATHING_RATE = '9279-1' # Breathing Rate
    HEART_RATE = '8867-4' # Heart Rate
    HEIGHT = '8302-2' # Height
    TEMPERATURE = '8310-5' # Temperature
    WEIGHT = '29463-7' # Weight

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
      "#{Settings.mhv.medical_records.host}/fhir/"
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
      result = fhir_client.search(FHIR::Patient, search: { parameters: { identifier: } })
      resource = result.resource
      handle_api_errors(result) if resource.nil?
      resource
    end

    def get_vaccine(vaccine_id)
      fhir_read(FHIR::Immunization, vaccine_id)
    end

    def list_vaccines
      fhir_search(FHIR::Immunization, search: { parameters: { patient: patient_fhir_id } })
    end

    def get_allergy(allergy_id)
      fhir_read(FHIR::AllergyIntolerance, allergy_id)
    end

    def list_allergies
      bundle = fhir_search(FHIR::AllergyIntolerance, search: { parameters: { patient: patient_fhir_id } })
      sort_bundle(bundle, :onsetDateTime, :desc)
    end

    def get_clinical_note(note_id)
      fhir_read(FHIR::DocumentReference, note_id)
    end

    def list_clinical_notes
      loinc_codes = "#{PHYSICIAN_PROCEDURE_NOTE},#{DISCHARGE_SUMMARY}"
      fhir_search(FHIR::DocumentReference,
                  search: { parameters: { patient: patient_fhir_id, type: loinc_codes } })
    end

    def get_diagnostic_report(record_id)
      fhir_search(FHIR::DiagnosticReport, search: { parameters: { _id: record_id, _include: '*' } })
    end

    ##
    # Fetch Lab & Tests results for the given patient. This combines the results of three separate calls.
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_and_tests(page_size = 999, page_num = 1)
      combined_bundle = FHIR::Bundle.new
      combined_bundle.type = 'searchset'

      # Make the individual API calls.
      labs_diagrep_chemhem = list_labs_chemhem_diagnostic_report
      labs_diagrep_other = list_labs_other_diagnostic_report
      labs_docref = list_labs_document_reference

      # TODO: Figure out how to do this in threads.
      # labs_diagrep_chemhem_thread = Thread.new { list_labs_chemhem_diagnostic_report(patient_id) }
      # labs_diagrep_other_thread = Thread.new { list_labs_other_diagnostic_report(patient_id) }
      # labs_docref_thread = Thread.new { list_labs_document_reference(patient_id) }
      # labs_diagrep_chemhem_thread.join
      # labs_diagrep_other_thread.join
      # labs_docref_thread.join
      # labs_diagrep_chemhem = labs_diagrep_chemhem_thread.value
      # labs_diagrep_other = labs_diagrep_other_thread.value
      # labs_docref = labs_docref_thread.value

      # Merge the entry arrays into the combined bundle.
      combined_bundle.entry.concat(labs_diagrep_chemhem.entry) if labs_diagrep_chemhem.entry
      combined_bundle.entry.concat(labs_diagrep_other.entry) if labs_diagrep_other.entry
      combined_bundle.entry.concat(labs_docref.entry) if labs_docref.entry

      # Ensure an accurate total count for the combined bundle.
      combined_bundle.total = (labs_diagrep_chemhem&.total || 0) + (labs_diagrep_other&.total || 0) +
                              (labs_docref&.total || 0)

      # Sort the combined_bundle.entry array by date in reverse chronological order
      sort_lab_entries(combined_bundle.entry)

      # Apply pagination
      combined_bundle.entry = paginate_bundle_entries(combined_bundle.entry, page_size, page_num)

      combined_bundle
    end

    def list_vitals
      loinc_codes = "#{BLOOD_PRESSURE},#{BREATHING_RATE},#{HEART_RATE},#{HEIGHT},#{TEMPERATURE},#{WEIGHT}"
      fhir_search(FHIR::Observation, search: { parameters: { patient: patient_fhir_id, code: loinc_codes } })
    end

    def get_condition(condition_id)
      fhir_search(FHIR::Condition, search: { parameters: { _id: condition_id, _include: '*' } })
    end

    def list_conditions
      fhir_search(FHIR::Condition, search: { parameters: { patient: patient_fhir_id } })
    end

    protected

    ##
    # Fetch Chemistry/Hematology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_chemhem_diagnostic_report
      fhir_search(FHIR::DiagnosticReport,
                  search: { parameters: { patient: patient_fhir_id, category: 'LAB' } })
    end

    ##
    # Fetch Microbiology and Pathology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_other_diagnostic_report
      loinc_codes = "#{MICROBIOLOGY},#{PATHOLOGY}"
      fhir_search(FHIR::DiagnosticReport, search: { parameters: { patient: patient_fhir_id, code: loinc_codes } })
    end

    ##
    # Fetch EKG and Radiology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_document_reference
      loinc_codes = "#{EKG},#{RADIOLOGY}"
      fhir_search(FHIR::DocumentReference,
                  search: { parameters: { patient: patient_fhir_id, type: loinc_codes } })
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
    # Perform a FHIR search. This method will return the first page of results only.
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
      body = JSON.parse(result.body)
      diagnostics = body['issue']&.first&.fetch('diagnostics', nil)
      diagnostics = "Error fetching data#{": #{diagnostics}" if diagnostics}"

      exception_class = case result.code
                        when 401
                          Common::Exceptions::Unauthorized
                        when 403
                          Common::Exceptions::Forbidden
                        when 500
                          if diagnostics.include? 'HAPI-1363'
                            # HAPI-1363: Either No patient or multiple patient found
                            Common::Exceptions::ResourceNotFound
                          else
                            Common::Exceptions::BadRequest
                          end
                        else
                          Common::Exceptions::BadRequest
                        end

      raise exception_class, { detail: diagnostics } if exception_class
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
    # @param field [Symbol] the field to sort on
    # @param order [Symbol] the sort order, :asc (default) or :desc
    #
    def sort_bundle(bundle, field, order = :asc)
      sorted_entries = bundle.entry.sort_by do |entry|
        if entry.resource.respond_to?(field) && !entry.resource.send(field).nil?
          [0, entry.resource.send(field)]
        else
          [1, Float::INFINITY]
        end
      end
      sorted_entries.reverse! if order == :desc
      bundle.entry = sorted_entries
      bundle
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
          -(entry.effectiveDateTime&.to_i || 0)
        when FHIR::DocumentReference
          -(entry.date&.to_i || 0)
        else
          0
        end
      end
    end
  end
end
