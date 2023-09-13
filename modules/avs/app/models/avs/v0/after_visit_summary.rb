# frozen_string_literal: true

require 'common/models/base'

module Avs
  class V0::AfterVisitSummary < Common::Base
    include ActiveModel::Serializers::JSON

    attribute :id, String
    attribute :icn, String
    attribute :meta, Object
    attribute :appointment_iens, Array
    attribute :clinics_visited, Array
    attribute :providers, Array
    attribute :reason_for_visit, Array
    attribute :diagnoses, Array
    attribute :vitals, Array
    attribute :orders, Array
    attribute :immunizations, Array
    attribute :appointments, Array
    attribute :patient_instructions, String
    attribute :patient_education, String
    attribute :primary_care_providers, Array
    attribute :primary_care_team, String
    attribute :primary_care_team_members, Array
    attribute :allergies_reactions, Object
    attribute :va_medications, Array
    attribute :lab_results, Array
    attribute :radiology_reports1_yr, String
    attribute :discrete_data, Object

    def initialize(data)
      super(data)
      set_attributes(data['data'])

      self.id = data['sid']
      self.icn = data['data']['patientInfo']['icn']
      self.appointment_iens = data['appointmentIens']
      self.meta = {
        generated_date: data['generatedDate'],
        time_zone: data['data']['header']['timeZone']
      }
    end

    private

    def set_attributes(data)
      data.each_key do |key|
        self[key.snakecase.to_sym] = data[key] if attributes.include?(key.snakecase.to_sym)
      end
    end
  end
end
