# frozen_string_literal: true

require 'common/models/concerns/active_record_cache_aside'
require 'sentry_logging'

# Account's purpose is to correlate unique identifiers, and to
# remove our dependency on third party services for a user's
# unique identifier.
#
# The account.uuid is intended to become the Vets-API user's uuid.
#
class Account < ApplicationRecord
  include Common::ActiveRecordCacheAside
  extend SentryLogging

  has_many :user_preferences, dependent: :destroy
  has_many :notifications, dependent: :destroy

  validates :uuid, presence: true, uniqueness: true
  validates :idme_uuid, uniqueness: true
  validates :idme_uuid, presence: true, unless: -> { sec_id.present? }
  validates :sec_id, presence: true, unless: -> { idme_uuid.present? }

  before_validation :initialize_uuid, on: :create

  attr_readonly :uuid

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
    key = get_key(user)
    acct = do_cached_with(key: key) do
      create_if_needed!(user)
    end
    # Account.sec_id was added months after this class was built, thus
    # the existing Account records (not new ones) need to have their
    # sec_id value updated
    update_if_needed!(acct, user)
  end

  def self.create_if_needed!(user)
    attrs = account_attrs_from_user(user)

    accts = where(idme_uuid: attrs[:idme_uuid])
            .where.not(idme_uuid: nil)
            .or(
              where(sec_id: attrs[:sec_id])
              .where.not(sec_id: nil)
            )

    if accts.length > 1
      data = accts.map(&:attributes)
      log_message_to_sentry('multiple Account records with matching ids', 'warning', data)
    end

    accts.length.positive? ? accts[0] : create(**attrs)
  end

  def self.update_if_needed!(account, user)
    # account has yet to be saved, no need to update
    return account unless account.persisted?

    # return account as is if all non-nil user attributes match up to be the same
    attrs = account_attrs_from_user(user).reject { |_k, v| v.nil? }

    return account if attrs.all? { |k, v| account.try(k) == v }

    diff = { account: account.attributes, user: attrs }
    log_message_to_sentry('Account record does not match User', 'warning', diff)
    updated = update(account.id, **attrs)
    cache_record(get_key(user), updated)
    updated
  end

  # Build an account attribute hash from the given User attributes
  #
  # @return [Hash]
  #
  def self.account_attrs_from_user(user)
    { idme_uuid: user.uuid, edipi: user.edipi, icn: user.icn, sec_id: user.sec_id }
  end

  # Determines if the associated Account record is cacheable. Required
  # method to accomodate the ActiveRecordCacheAside API.
  #
  # @return [Boolean]
  #
  def cache?
    persisted?
  end

  def self.get_key(user)
    user.uuid || "sec:#{user.sec_id}"
  end

  private_class_method :account_attrs_from_user, :get_key

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
