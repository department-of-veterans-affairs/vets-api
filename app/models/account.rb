# frozen_string_literal: true

require 'common/models/concerns/active_record_cache_aside'

# Account's purpose is to correlate unique identifiers, and to
# remove our dependency on third party services for a user's
# unique identifier.
#
# The account.uuid is intended to become the Vets-API user's uuid.
#
class Account < ApplicationRecord
  include Common::ActiveRecordCacheAside

  has_many :user_preferences, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :idme_uuid, uniqueness: true
  validates :idme_uuid, presence: true, unless: -> { sec_id.present? }
  validates :sec_id, presence: true, unless: -> { idme_uuid.present? }

  before_validation :initialize_uuid, on: :create

  attr_readonly :uuid

  USER_ATTR_HASH = { idme_uuid: 'uuid', edipi: 'edipi', icn: 'icn', sec_id: 'sec_id' }.freeze

  # Required for configuring mixed in ActiveRecordCacheAside module.
  # Redis settings for ttl and namespacing reside in config/redis.yml
  #
  redis REDIS_CONFIG['user_account_details']['namespace']
  redis_ttl REDIS_CONFIG['user_account_details']['each_ttl']

  # Returns the one Account record for the passed in user.
  #
  # Will first attempt to return the cached record.  If one does
  # not exist, it will find/create one, and cache it before returning it.
  #
  # @param user [User] An instance of User
  # @return [Account] A persisted instance of Account
  #
  def self.cache_or_create_by!(user)
    return unless user.uuid || user.sec_id

    # if possible use the idme uuid for the key, fallback to using the sec id otherwise
    key = user.uuid ? "idme:#{user.uuid}" : "sec:#{user.sec_id}"
    acct = do_cached_with(key: key) do
      create_if_needed!(user)
    end
    # Account.sec_id was added months after this class was built, thus
    # the existing Account records (not new ones) need to have their
    # sec_id value updated
    update_if_needed!(acct, user)
  end

  def self.create_if_needed!(user)
    accounts = where('idme_uuid = :u OR sec_id = :s',
                     u: user.send(USER_ATTR_HASH[:idme_uuid]), s: user.send(USER_ATTR_HASH[:sec_id]))

    if accounts.length > 1
      # TODO: are any ids in an Account record considered PII? if so we need
      # to change the extra_context value
      log_message_to_sentry(
        'multiple Account records with matching ids',
        'warning',
        accounts
      )
    end

    return accounts[0] if accounts.length > 0

    create(**USER_ATTR_HASH.map { |k, v| [k, user.send(v)] }.to_h)
  end

  def self.update_if_needed!(account, user)
    # return account as is if all user attributes match up to be the same
    return account if USER_ATTR_HASH.all? { |k, v| account.send(k) == user.send(v) }

    update(account.id, **USER_ATTR_HASH.map { |k, v| [k, user.send(v)] }.to_h)
  end

  # Determines if the associated Account record is cacheable. Required
  # method to accomodate the ActiveRecordCacheAside API.
  #
  # @return [Boolean]
  #
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
