# frozen_string_literal: true

require 'common/models/base'

module Avs
  class V0::AfterVisitSummary < Common::Base
    include ActiveModel::Serializers::JSON

    attribute :id, String
    attribute :icn, String
    attribute :meta, Object
    attribute :patient_info, Object
    attribute :appointment_iens, Array
    attribute :clinics_visited, Array
    attribute :providers, Array
    attribute :reason_for_visit, Array
    attribute :diagnoses, Array
    attribute :vitals, Array
    attribute :orders, Array
    attribute :procedures, Array
    attribute :immunizations, Array
    attribute :appointments, Array
    attribute :patient_instructions, String
    attribute :patient_education, String
    attribute :pharmacy_terms, Array
    attribute :primary_care_providers, Array
    attribute :primary_care_team, String
    attribute :primary_care_team_members, Array
    attribute :problems, Array
    attribute :clinical_reminders, Array
    attribute :clinical_services, Array
    attribute :allergies_reactions, Object
    attribute :clinic_medications, Array
    attribute :va_medications, Array
    attribute :nonva_medications, Array
    attribute :med_changes_summary, Object
    attribute :lab_results, Array
    attribute :radiology_reports1_yr, String
    attribute :discrete_data, Object
    attribute :more_help_and_information, String

    def initialize(data)
      super(data)
      set_attributes(data['data'])

      self.id = data['sid']
      self.icn = data.dig('data', 'patientInfo', 'icn')
      self.appointment_iens = data['appointmentIens']
      self.meta = {
        generated_date: data['generatedDate'],
        station_no: data.dig('data', 'header', 'stationNo'),
        page_header: sanitize_html(data.dig('data', 'header', 'pageHeader')),
        time_zone: data.dig('data', 'header', 'timeZone')
      }
      self.patient_info = {
        smoking_status: data.dig('data', 'patientInfo', 'smokingStatus') || ''
      }
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

    def set_attributes(data)
      data.each_key do |key|
        self[key.snakecase.to_sym] = data[key] if attributes.include?(key.snakecase.to_sym)
      end
    end
  end
end
