# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class AppointmentRequestForm < Common::Form
    attribute :email, String
    attribute :phone_number, String
    attribute :option_date1, String
    attribute :option_time1, String
    attribute :option_date2, String
    attribute :option_time2, String
    attribute :option_date3, String
    attribute :option_time3, String
    attribute :status, String
    attribute :appointment_type, String
    attribute :visit_type, String
    attribute :text_messaging_allowed, Boolean
    attribute :phone_number, String
    attribute :purpose_of_visit, String
    attribute :other_purpose_of_visit, String
    attribute :purpose_of_visit, String
    attribute :provider_id, String
    attribute :second_request, Boolean
    attribute :second_request_submitted, Boolean
    attribute :provider_name, String
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, Boolean
    attribute :has_veteran_new_message, Boolean
    attribute :has_provider_new_message, Boolean
    attribute :provider_seen_appointment_request, Boolean
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, String
    attribute :patient_id, String # This setter is overriden
    attribute :appointment_request_id, String # This setter is overriden
    attribute :unique_id, String # This setter is overriden
    attribute :id, String # This setter is overriden
    attribute :date, Time, default: Time.current.strftime('%Y-%m-%dT%H:%M:%S.%L%z')
    attribute :assigning_authority, String, default: 'ICN'
    attribute :system_id, String, default: 'var'
    attribute :object_type, String, default: 'VARAppointmentRequest'
    attribute :surrogate_identifier, Hash, default: {}
    attribute :facility, Hash
    attribute :patient, Hash, default: { inpatient: false, text_messaging_allowed: false } # This setter is overriden
    attribute :best_timeto_call, Array[String]
    attribute :appointment_request_detail_code, Array[String] # This setter is overriden

    def initialize(user, json_hash)
      @user = user
      @id = json_hash[:id]
      @unique_id = @id
      @appointment_request_id = @id
      super(json_hash)
    end

    def facility=(values_hash)
      @facility = values_hash.empty? ? {} : values_hash.merge(object_type: 'Facility').compact
    end

    def patient=(values_hash)
      @patient = {
        display_name: "#{last_name}, #{first_name}",
        first_name: first_name,
        last_name: last_name,
        date_of_birth: dob,
        patient_identifier: {
          unique_id: edipi
        },
        ssn: ssn,
        inpatient: values_hash[:inpatient],
        text_messaging_allowed: values_hash[:text_messaging_allowed],
        id: edipi,
        object_type: 'Patient'
      }.compact
    end

    def appointment_request_detail_code=(array_of_detail_codes)
      @appointment_request_detail_code = Array.wrap(array_of_detail_codes).map do |code|
        {
          user_id: @user.icn,
          detail_code: { code: (code.is_a?(Hash) ? code[:detail_code][:code] : code)  }
        }
      end
    end

    def appointment_request_id=(_value)
      @appointment_request_id = @id
    end

    def id=(_value)
      @id
    end

    def unique_id=(_value)
      @unique_id = @id
    end

    def patient_id=(_value)
      @patient_id = edipi
    end

    def params
      # TODO: FE to do discovery on possible validations we might add.
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes.compact
    end

    private

    def first_name
      @user.mvi&.profile&.given_names&.first
    end

    def last_name
      @user.mvi&.profile&.family_name
    end

    def dob
      Date.parse(@user.mvi.profile.birth_date).strftime('%b %d, %Y') rescue ''
    end

    def edipi
      @user.mvi&.profile&.edipi
    end

    def ssn
      @user.mvi&.profile&.ssn
    end
  end
end
