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
    attribute :immunizations
    attribute :appointments
    attribute :patient_instructions
    attribute :patient_education
    attribute :primary_care_providers
    attribute :primary_care_team
    attribute :primary_care_team_members
    attribute :allergies_reactions
    attribute :va_medications
    attribute :lab_results
    attribute :radiology_reports1_yr
    attribute :discrete_data
  end
end
