# frozen_string_literal: true

class MHVUserAccountSerializer
  include JSONAPI::Serializer

  set_id(&:user_profile_id)

  attributes :user_profile_id, :premium, :champ_va, :patient, :sm_account_created, :message
end
