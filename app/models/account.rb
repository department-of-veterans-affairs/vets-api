# frozen_string_literal: true

# Account's purpose is to correlate unique identifiers, and to
# remove our dependency on third party services for a user's
# unique identifier.
#
# The account.uuid is intended to become the Vets-API user's uuid.
#
class Account < ActiveRecord::Base
  has_many :user_preferences, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :idme_uuid, presence: true, uniqueness: true

  before_validation :initialize_uuid, on: :create

  attr_readonly :uuid

  def self.create_if_needed!(user)
    find_or_create_by!(idme_uuid: user.uuid) do |account|
      account.edipi = user&.edipi
      account.icn   = user&.icn
    end
  end

  private

  def initialize_uuid
    new_uuid  = generate_uuid
    new_uuid  = generate_uuid until unique?(new_uuid)
    self.uuid = new_uuid
  end

  def unique?(new_uuid)
    return true unless Account.exists?(uuid: new_uuid)
  end

  def generate_uuid
    SecureRandom.uuid
  end
end
