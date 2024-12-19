# frozen_string_literal: true

class MHVUserAccount
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :user_profile_id, :string
  attribute :premium, :boolean
  attribute :champ_va, :boolean
  attribute :patient, :boolean
  attribute :sm_account_created, :boolean
  attribute :message, :string
  alias_attribute :id, :user_profile_id

  validates :user_profile_id, presence: true
  validates :premium, :champ_va, :patient, :sm_account_created, inclusion: { in: [true, false] }
end
