# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class MessageForm < Common::Form
    attribute :message_text, String # only this attribute gets set by user, everything else is overridden
    attribute :url, String
    attribute :sender_id, String
    attribute :appointment_request_id, String
    attribute :message_date_time, String
    attribute :message_sent, Boolean
    attribute :is_last_message, Boolean
    attribute :_appointment_request_id, String

    def initialize(user, request_id, json_hash = {})
      super(json_hash)
      @user = user
      @appointment_request_id = request_id
    end

    # DOWNSTREAM_BUG: addresses the fact that downstream requires this as AppointmentRequestId (upper camelcase)
    def _appointment_request_id
      appointment_request_id
    end

    def url
      ''
    end

    def sender_id
      @user.icn
    end

    def message_date_time
      ''
    end

    def message_sent
      true
    end

    # rubocop:disable Naming/PredicateName
    def is_last_message
      true
    end
    # rubocop:enable Naming/PredicateName

    validates :message_text, length: { minimum: 1, maximum: 100 }

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes
    end
  end
end
