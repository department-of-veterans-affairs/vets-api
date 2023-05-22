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
      fhir_client.search(FHIR::DocumentReference,
                         search: { parameters: { patient: patient_id, type: '83320-2,18842-5,11505-5' } }).resource
    end

    def get_diagnostic_report(record_id)
      fhir_client.search(FHIR::DiagnosticReport, search: { parameters: { _id: record_id, _include: '*' } }).resource
    end

    def list_labs_and_tests(patient_id)
      fhir_client.search(FHIR::DiagnosticReport,
                         search: { parameters: { patient: patient_id, category: 'LAB' } }).resource
    end
  end
end
