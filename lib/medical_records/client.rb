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
    DEFAULT_COUNT = 100

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

    def fhir_client
      # FHIR debug level is extremely verbose, printing the full contents of every response body.
      ::FHIR.logger.level = Logger::INFO

      FHIR::Client.new(base_path).tap do |client|
        client.use_r4
        client.default_json
        client.use_minimal_preference
        client.set_bearer_token(jwt_bearer_token)
      end
    end

    def get_vaccine(vaccine_id)
      fhir_search(FHIR::Immunization, search: { parameters: { _id: vaccine_id, _include: '*' } })
    end

    def list_vaccines(patient_id)
      fhir_search(FHIR::Immunization, search: { parameters: { patient: patient_id } })
    end

    def get_allergy(allergy_id)
      fhir_read(FHIR::AllergyIntolerance, allergy_id)
    end

    def list_allergies(patient_id)
      fhir_search(FHIR::AllergyIntolerance, search: { parameters: { patient: patient_id } })
    end

    def get_clinical_note(note_id)
      fhir_read(FHIR::DocumentReference, note_id)
    end

    def list_clinical_notes(patient_id)
      loinc_codes = "#{PHYSICIAN_PROCEDURE_NOTE},#{DISCHARGE_SUMMARY}"
      fhir_search(FHIR::DocumentReference,
                  search: { parameters: { patient: patient_id, type: loinc_codes } })
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
    def list_labs_and_tests(patient_id, page_size = 999, page_num = 1)
      combined_bundle = FHIR::Bundle.new
      combined_bundle.type = 'searchset'

      # Make the individual API calls.
      labs_diagrep_chemhem = list_labs_chemhem_diagnostic_report(patient_id)
      labs_diagrep_other = list_labs_other_diagnostic_report(patient_id)
      labs_docref = list_labs_document_reference(patient_id)

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

    def list_vitals(patient_id)
      loinc_codes = "#{BLOOD_PRESSURE},#{BREATHING_RATE},#{HEART_RATE},#{HEIGHT},#{TEMPERATURE},#{WEIGHT}"
      fhir_search(FHIR::Observation, search: { parameters: { patient: patient_id, code: loinc_codes } })
    end

    def get_condition(condition_id)
      fhir_search(FHIR::Condition, search: { parameters: { _id: condition_id, _include: '*' } })
    end

    def list_conditions(patient_id)
      fhir_search(FHIR::Condition, search: { parameters: { patient: patient_id } })
    end

    protected

    ##
    # Fetch Chemistry/Hematology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_chemhem_diagnostic_report(patient_id)
      fhir_search(FHIR::DiagnosticReport,
                  search: { parameters: { patient: patient_id, category: 'LAB' } })
    end

    ##
    # Fetch Microbiology and Pathology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_other_diagnostic_report(patient_id)
      loinc_codes = "#{MICROBIOLOGY},#{PATHOLOGY}"
      fhir_search(FHIR::DiagnosticReport, search: { parameters: { patient: patient_id, code: loinc_codes } })
    end

    ##
    # Fetch EKG and Radiology results for the given patient
    #
    # @param patient_id [Fixnum] MHV patient ID
    # @return [FHIR::Bundle]
    #
    def list_labs_document_reference(patient_id)
      loinc_codes = "#{EKG},#{RADIOLOGY}"
      fhir_search(FHIR::DocumentReference,
                  search: { parameters: { patient: patient_id, type: loinc_codes } })
    end

    def fhir_search(fhir_model, params)
      params[:search][:parameters].merge!(_count: DEFAULT_COUNT)
      result = fhir_client.search(fhir_model, params)
      handle_api_errors(result) if result.resource.nil?
      result.resource
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
