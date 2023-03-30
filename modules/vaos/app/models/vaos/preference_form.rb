# frozen_string_literal: true

require 'active_model'
require 'common/models/form'
require 'common/exceptions'

module VAOS
  class PreferenceForm < Common::Form
    attribute :notification_frequency, String
    attribute :email_allowed, Boolean
    attribute :email_address, String
    attribute :text_msg_allowed, Boolean
    attribute :text_msg_ph_number, String
    attribute :patient_identifier, Hash # overridden Getter method; this field should be ignored if passed in by FE
    attribute :patient_id, String # overridden Getter method; this field should be ignored if passed in by FE
    attribute :assigning_authority, String # overridden Getter method; this field should be ignored if passed in by FE

    validates :notification_frequency, presence: true

    def initialize(user, json_hash = {})
      super(json_hash)
      @user = user
    end

    def params
      raise Common::Exceptions::ValidationErrors, self unless valid?

      attributes.compact
    end

    # The following values are all overridden, needed by VAMF, but should not be passed in by FE.
    def assigning_authority
      'ICN'
    end

    def patient_id
      @user.icn
    end

    def patient_identifier
      {
        unique_id: patient_id,
        assigning_authority:
      }
    end
  end
end
