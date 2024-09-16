# frozen_string_literal: true

class MHVUserAccount
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :user_profile_id, :string
  attribute :champ_va, :boolean
  attribute :patient, :boolean
  attribute :sm_account, :boolean

  validates :user_profile_id, presence: true
  validates :champ_va, :patient, :sm_account, inclusion: { in: [true, false] }
end
