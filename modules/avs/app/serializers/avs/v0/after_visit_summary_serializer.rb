# frozen_string_literal: true

module Avs
  class V0::AfterVisitSummarySerializer
    include JSONAPI::Serializer

    set_key_transform :camel_lower

    attribute :id
    attribute :appointment_iens
    attribute :meta
    attribute :clinics_visited
    attribute :providers
    attribute :reason_for_visit
    attribute :diagnoses
    attribute :vitals
    attribute :orders
    attribute :procedures
    attribute :immunizations
    attribute :appointments
    attribute :patient_info
    attribute :patient_instructions
    attribute :patient_education
    attribute :pharmacy_terms
    attribute :primary_care_providers
    attribute :primary_care_team
    attribute :primary_care_team_members
    attribute :problems
    attribute :clinical_reminders
    attribute :clinical_services
    attribute :allergies_reactions
    attribute :clinic_medications
    attribute :va_medications
    attribute :nonva_medications
    attribute :med_changes_summary
    attribute :lab_results
    attribute :radiology_reports1_yr
    attribute :discrete_data
    attribute :more_help_and_information
  end
end
