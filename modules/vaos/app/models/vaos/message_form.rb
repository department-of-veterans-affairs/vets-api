# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class MessageForm < Common::Form
    attribute :message_text, String # maximum 100
    attribute :url, String # -- i think this is just a returned value when created, but will verify.
    attribute :sender_id, String # -- this might be inferred, but probably required, will verify.
    attribute :appointment_request_id, String # -- i think this is just a return value, the id is in the url
    attribute :message_date_time, String # -- i think this is just a return value
    attribute :message_sent, Boolean, default: true # -- i think this is just a return value
    attribute :is_last_message, Boolean, default: true # -- i think this is just a return value
    attribute :_appointment_request_id, String

    # Hack: addresses the fact that downstream requires this as AppointmentRequestId (upper camelcase)
    def _appointment_request_id
      appointment_request_id
    end

    # validates :appointment_request_id, presence: true
    validates :message_text, length: { minimum: 1, maximum: 100 } 

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
