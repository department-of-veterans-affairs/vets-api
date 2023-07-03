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
    # loinc codes for clinical notes
    PHYSICIAN_PROCEDURE_NOTE = '11505-5' # Physician procedure note
    DISCHARGE_SUMMARY = '18842-5' # Discharge summary

    # loinc codes for vitals
    BLOOD_PRESSURE = '85354-9' # Blood Pressure
    BREATHING_RATE = '9279-1' # Breathing Rate
    HEART_RATE = '8867-4' # Heart Rate
    HEIGHT = '8302-2' # Height
    TEMPERATURE = '8310-5' # Temperature
    WEIGHT = '29463-7' # Weight

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

    def list_labs_and_tests(patient_id)
      fhir_search(FHIR::DiagnosticReport,
                  search: { parameters: { patient: patient_id, category: 'LAB' } })
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

    def fhir_search(fhir_model, params)
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
  end
end
