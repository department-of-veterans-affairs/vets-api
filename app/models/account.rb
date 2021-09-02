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

  has_many :notifications, dependent: :destroy
  has_many :preferred_facilities, dependent: :destroy, inverse_of: :account
  has_one  :login_stats,
           class_name: 'AccountLoginStat',
           dependent: :destroy,
           inverse_of: :account

  validates :uuid, presence: true, uniqueness: true
  validates :idme_uuid, uniqueness: true
  validates :idme_uuid, presence: true, unless: -> { sec_id.present? }
  validates :sec_id, presence: true, unless: -> { idme_uuid.present? }

  before_validation :initialize_uuid, on: :create

  attr_readonly :uuid

  # Required for configuring mixed in ActiveRecordCacheAside module.
  # Redis settings for ttl and namespacing reside in config/redis.yml
  #
  redis REDIS_CONFIG[:user_account_details][:namespace]
  redis_ttl REDIS_CONFIG[:user_account_details][:each_ttl]

  scope :idme_uuid_match, lambda { |v|
                            if v.present?
                              where(idme_uuid: v)
                            else
                              none
                            end
                          }
  scope :sec_id_match, lambda { |v|
                         if v.present?
                           where(sec_id: v)
                         else
                           none
                         end
                       }

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

    acct = do_cached_with(key: get_key(user)) do
      create_if_needed!(user)
    end
    # Account.sec_id was added months after this class was built, thus
    # the existing Account records (not new ones) need to have their
    # sec_id value updated
    update_if_needed!(acct, user)
  end

  def self.create_if_needed!(user)
    accts = idme_uuid_match(user.idme_uuid).or(sec_id_match(user.sec_id))
    accts = sort_with_idme_uuid_priority(accts, user)
    accts.length.positive? ? accts[0] : create(**account_attrs_from_user(user))
  end

  def self.update_if_needed!(account, user)
    # account has yet to be saved, no need to update
    return account unless account.persisted?

    # return account as is if all non-nil user attributes match up to be the same
    attrs = account_attrs_from_user(user).compact

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
    {
      idme_uuid: user.idme_uuid,
      sec_id: user.sec_id,
      edipi: user.edipi,
      icn: user.icn
    }
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

  # Sort the given list of Accounts so the ones with matching ID.me UUID values
  # come first in the array, this will provide users with a more consistent
  # experience in the case they have multiple credentials to login with
  # https://github.com/department-of-veterans-affairs/va.gov-team/issues/6702
  #
  # @return [Array]
  #
  def self.sort_with_idme_uuid_priority(accts, user)
    if accts.length > 1
      data = accts.map { |a| "Account:#{a.id}" }
      log_message_to_sentry('multiple Account records with matching ids', 'warning', data)
      accts = accts.sort_by { |a| a.idme_uuid == user.idme_uuid ? 0 : 1 }
    end
    accts
  end

  private_class_method :account_attrs_from_user, :get_key, :sort_with_idme_uuid_priority

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
