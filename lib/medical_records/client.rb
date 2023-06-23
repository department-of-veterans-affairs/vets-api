# frozen_string_literal: true

require 'common/client/base'
require 'common/client/concerns/mhv_session_based_client'
# require 'medical_records/client_session'
require 'medical_records/configuration'

module MedicalRecords
  ##
  # Core class responsible for Medical Records API interface operations
  #
  class Client < Common::Client::Base
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

    ##
    # @return [String] Base path for dependent URLs
    #
    def base_path
      "#{Settings.mhv.medical_records.host}/baseR4/"
    end

    def fhir_client
      FHIR::Client.new(base_path).tap do |client|
        client.use_r4
        client.default_json
        client.set_no_auth
        client.use_minimal_preference
      end
      # options = client.get_oauth2_metadata_from_conformance
      # client.set_bearer_token(client_secret)
    end

    def get_vaccine(vaccine_id)
      # fhir_client.read(FHIR::Immunization, vaccine_id).resource
      fhir_client.search(FHIR::Immunization, search: { parameters: { _id: vaccine_id, _include: '*' } }).resource
    end

    def list_vaccines(patient_id)
      fhir_client.search(FHIR::Immunization, search: { parameters: { patient: patient_id } }).resource
    end

    def get_allergy(allergy_id)
      fhir_client.read(FHIR::AllergyIntolerance, allergy_id).resource
    end

    def list_allergies(patient_id)
      fhir_client.search(FHIR::AllergyIntolerance, search: { parameters: { patient: patient_id } }).resource
    end

    def get_clinical_note(note_id)
      fhir_client.read(FHIR::DocumentReference, note_id).resource
    end

    def list_clinical_notes(patient_id)
      loinc_codes = "#{PHYSICIAN_PROCEDURE_NOTE},#{DISCHARGE_SUMMARY}"
      fhir_client.search(FHIR::DocumentReference,
                         search: { parameters: { patient: patient_id, type: loinc_codes } }).resource
    end

    def get_diagnostic_report(record_id)
      fhir_client.search(FHIR::DiagnosticReport, search: { parameters: { _id: record_id, _include: '*' } }).resource
    end

    def list_labs_and_tests(patient_id)
      fhir_client.search(FHIR::DiagnosticReport,
                         search: { parameters: { patient: patient_id, category: 'LAB' } }).resource
    end

    def list_vitals(patient_id)
      loinc_codes = "#{BLOOD_PRESSURE},#{BREATHING_RATE},#{HEART_RATE},#{HEIGHT},#{TEMPERATURE},#{WEIGHT}"
      fhir_client.search(FHIR::Observation, search: { parameters: { patient: patient_id, code: loinc_codes } }).resource
    end

    def get_condition(condition_id)
      fhir_client.search(FHIR::Condition, search: { parameters: { _id: condition_id, _include: '*' } }).resource
    end

    def list_conditions(patient_id)
      fhir_client.search(FHIR::Condition, search: { parameters: { patient: patient_id } }).resource
    end
  end
end
