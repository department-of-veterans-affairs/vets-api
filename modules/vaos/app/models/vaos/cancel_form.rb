# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class CancelForm < Common::Form
    attribute :appointment_time, VAOS::AppointmentTime
    attribute :clinic_id, String
    attribute :cancel_reason, String
    attribute :cancel_code, String
    attribute :remarks, String
    attribute :clinic_name, String

    validates :appointment_time, :cancel_code, presence: true

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
