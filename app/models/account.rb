# frozen_string_literal: true

require 'common/models/concerns/active_record_cache_aside'

# Account's purpose is to correlate unique identifiers, and to
# remove our dependency on third party services for a user's
# unique identifier.
#
# The account.uuid is intended to become the Vets-API user's uuid.
#
class Account < ActiveRecord::Base
  include Common::ActiveRecordCacheAside

  has_many :user_preferences, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :idme_uuid, presence: true, uniqueness: true

  before_validation :initialize_uuid, on: :create

  attr_readonly :uuid

  # Redis settings for ttl and namespacing reside in config/redis.yml
  #
  redis REDIS_CONFIG['user_account_details']['namespace']
  redis_ttl REDIS_CONFIG['user_account_details']['each_ttl']

  def self.cache_or_create_by!(user)
    return unless user.uuid

    do_cached_with(key: user.uuid) do
      create_if_needed!(user)
    end
  end

  def self.create_if_needed!(user)
    find_or_create_by!(idme_uuid: user.uuid) do |account|
      account.edipi = user&.edipi
      account.icn   = user&.icn
    end
  end

  def cache?
    persisted?
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
