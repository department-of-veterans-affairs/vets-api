# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class MessageForm < Common::Form
    
    # here's what's in the POST message in current VAR
    # isLastMessage  true
    # messageDateTime  ""  (looks set in back end regardless if value passed)
    # messageSent  true
    # messageText
    # senderId  (patient id)
    # url  ""

    attribute :appointment_request_id, String
    attribute :is_last_message, Boolean
    attribute :message_date_time, String 
    attribute :message_sent, String
    attribute :message_text, String
    attribute :sender_id, String
    attribute :url, String

    validates :message_text, length: { in: 1..100,
      wrong_length: "Appointment request message is required and must be between 1 and 100 characters"  }

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end

  end
end
