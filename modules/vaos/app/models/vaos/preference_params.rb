module VAOS
  class PreferenceParams < Dry::Schema::Params
    define do
      required(:notification_frequency).filled(:string)
      optional(:email_allowed).filled(:bool)
      optional(:email_address).filled(:string)
      optional(:text_msg_allowed).filled(:bool)
      optional(:text_msg_ph_number).maybe(:string)
    end

    def initialize(params, user)
      @params = params
      @user = user
    end

    def to_h
      result = call(params)
      raise Common::Exceptions::ValidationErrors, result.errors(full: true) if result.failure?
      to_h.merge(patient_identifier: { unique_id: user.icn, assigning_authority: 'ICN'})
    end
  end
end
