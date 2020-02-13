# frozen_string_literal: true

module VAOS
  class PreferenceParams < Params
    def to_h
      super.to_h.merge(patient_identifier: { unique_id: @user.icn, assigning_authority: 'ICN' })
    end

    private

    def schema
      Dry::Schema.Params do
        required(:notification_frequency).filled(:string)
        optional(:email_allowed).filled(:bool)
        optional(:email_address).filled(:string)
        optional(:text_msg_allowed).filled(:bool)
        optional(:text_msg_ph_number).maybe(:string)
      end
    end
  end
end
