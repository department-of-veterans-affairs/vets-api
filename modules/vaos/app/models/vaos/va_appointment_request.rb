# frozen_string_literal: true

require 'common/models/form'

module VAOS
  class VAAppointmentRequest < Common::Form
    include ActiveModel::Validations

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
    attribute :best_time_to_call, Array[String]
    attribute :provider_name, String
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, Boolean
    attribute :has_veteran_new_message, Boolean
    attribute :has_provider_new_message, Boolean
    attribute :provider_seen_appointment_request, Boolean
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, String
    attribute :patient_id, String
    attribute :date, Time # "2019-11-05_t1 5 49.372+0000"
    attribute :assigning_authority, String
    attribute :system_id, String
    attribute :appointment_request_id, String
    attribute :unique_id, String
    attribute :id, String
    attribute :facility, VAOS::Facility
    attribute :patient, VAOS::Patient
    attribute :appointment_request_detail_code, Array[Hash]

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
