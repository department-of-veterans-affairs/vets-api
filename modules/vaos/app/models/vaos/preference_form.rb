# frozen_string_literal: true

require 'active_model'
require 'common/models/form'

module VAOS
  class PreferenceForm < Common::Form
    attribute :notification_frequency, String
    attribute :email_allowed, Boolean
    attribute :email_address, String
    attribute :text_msg_allowed, Boolean
    attribute :text_msg_ph_number, String
    attribute :patient_identifier, Hash
    attribute :patient_id, String
    attribute :assigning_authority, String
    attribute :object_type, String

    def initialize(user, json_hash = {})
      super(json_hash)
      @user = user
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes.compact
    end

    def assigning_authority
      'ICN'
    end

    def patient_id
      @user.icn
    end

    def patient_identifier
      {
        unique_id: patient_id
        assigning_authority: assigning_authority,
      }
    end
  end
end
