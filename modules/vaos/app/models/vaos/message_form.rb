# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class MessageForm < Common::Form
    # attribute :appointment_request_id, String -- i think this is just a return value, the id is in the url
    # attribute :is_last_message, Boolean -- i think this is just a return value
    # attribute :message_date_time, String -- i think this is just a return value
    # attribute :message_sent, String -- i think this is just a return value
    attribute :message_text, String # maximum 100
    # attribute :sender_id, String -- this might be inferred, but probably required, will verify.
    # attribute :url, String  -- i think this is just a returned value when created, but will verify.

    # validates :appointment_request_id, presence: true
    validates :message_text, length: { minimum: 1, maximum: 100 } 

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
