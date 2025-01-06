# frozen_string_literal: true

require 'vets/model'

module Avs
  class V0::AfterVisitSummary
    include Vets::Model

    attribute :id, String
    attribute :icn, String
    attribute :meta, Hash
    attribute :patient_info, Hash
    attribute :appointment_iens, Array, default: []
    attribute :clinics_visited, Array, default: []
    attribute :providers, Array, default: []
    attribute :reason_for_visit, Array, default: []
    attribute :diagnoses, Array, default: []
    attribute :vitals, Array, default: []
    attribute :orders, Array, default: []
    attribute :procedures, Array, default: []
    attribute :immunizations, Array, default: []
    attribute :appointments, Array, default: []
    attribute :patient_instructions, String
    attribute :patient_education, String
    attribute :pharmacy_terms, Array, default: []
    attribute :primary_care_providers, Array, default: []
    attribute :primary_care_team, String
    attribute :primary_care_team_members, Array, default: []
    attribute :problems, Array, default: []
    attribute :clinical_reminders, Array, default: []
    attribute :clinical_services, Array, default: []
    attribute :allergies_reactions, Hash
    attribute :clinic_medications, Array, default: []
    attribute :va_medications, Array, default: []
    attribute :nonva_medications, Array, default: []
    attribute :med_changes_summary, Hash
    attribute :lab_results, Array, default: []
    attribute :radiology_reports1_yr, String
    attribute :discrete_data, Hash
    attribute :more_help_and_information, String

    def initialize(data)
      attributes = flatten_attributes(data['data'])
      attributes[:id] = data['sid']
      attributes[:icn] = data.dig('data', 'patientInfo', 'icn')
      attributes[:appointment_iens] = data['appointmentIens']
      attributes[:meta] = {
        generated_date: data['generatedDate'],
        station_no: data.dig('data', 'header', 'stationNo'),
        page_header: sanitize_html(data.dig('data', 'header', 'pageHeader')),
        time_zone: data.dig('data', 'header', 'timeZone')
      }
      attributes[:patient_info] = {
        smoking_status: data.dig('data', 'patientInfo', 'smokingStatus') || ''
      }
      super(attributes)
    end

    private

    def sanitize_html(html)
      if html
        Sanitize.fragment(html, Sanitize::Config.merge(Sanitize::Config::BASIC,
                                                       elements: [],
                                                       whitespace_elements: {
                                                         'div' => { before: '', after: "\n" }
                                                       })).strip
      end
    end

    def flatten_attributes(data)
      transformed_data = {}
      data.each_key do |key|
        transformed_key = key.to_s.snakecase.to_sym
        transformed_data[transformed_key] = data[key] if self.class.attribute_set.include?(transformed_key)
      end
      transformed_data
    end

    def as_json(options = {})
      super(options).deep_transform_keys { |key| key.snakecase.to_sym }
    end
  end
end
