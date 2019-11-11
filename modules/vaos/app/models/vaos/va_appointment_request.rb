# frozen_string_literal: true

require 'common/models/form'
require 'common/models/attribute_types/httpdate'

module VAOS
  class VAAppointmentRequest < Common::Form
    include ActiveModel::Validations

    attribute :appointment_type, String
    attribute :visit_type, String
    attribute :facility, VAOS::Facility
    attribute :email, String
    attribute :phone_number, String
    attribute :option_date1, String
    attribute :option_time1, String
    attribute :option_date2, String
    attribute :option_time2, String
    attribute :option_date3, String
    attribute :option_time3, String
    attribute :best_time_to_call, String
    attribute :purpose_of_visit, String
    attribute :other_purpose_of_visit, String
    attribute :status, String
    attribute :purpose_of_visit, String
    attribute :provider_id, String
    attribute :second_request, Boolean
    attribute :provider_name, String
    attribute :text_messaging_allowed, Boolean
    attribute :text_messaging_phone_number, String
    attribute :requested_phone_call, Boolean
    attribute :type_of_care_id, Boolean

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      Hash[attribute_set.map do |attribute|
        value = send(attribute.name)
        [attribute.name, value] unless value.nil?
      end.compact]
    end
  end
end
