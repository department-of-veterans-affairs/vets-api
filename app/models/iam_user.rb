# frozen_string_literal: true

require 'digest'
require 'active_support/core_ext/digest/uuid'

# Subclasses the `User` model. Adds a unique redis namespace for IAM users.
# Adds IAM sourced versions of ICN, EDIPI, and SEC ID and methods to use them
# or hit MPI via the va_profile method.
#
class IAMUser < ::User
  redis_store REDIS_CONFIG[:iam_user][:namespace]
  redis_ttl REDIS_CONFIG[:iam_user][:each_ttl]
  redis_key :uuid

  attribute :expiration_timestamp, Integer
  attribute :iam_icn, String
  attribute :iam_edipi, String
  attribute :iam_sec_id, String

  # MVI::Service uses 'mhv_icn' to query by icn rather than less accurate user traits
  alias mhv_icn iam_icn

  # Builds an user instance from a IAMUserIdentity
  #
  # @param iam_identity [IAMUserIdentity] the IAM identity object.
  # @return [IAMUser] an instance of this class
  #
  def self.build_from_user_identity(user_identity)
    user = new(user_identity.attributes)
    user.set_expire
    user
  end

  # Where to get the edipi from
  # If iam_edipi available return that otherwise hit MVI
  # @return [String] the users DoD EDIPI
  #
  def edipi
    loa3? && iam_edipi.present? ? iam_edipi : mpi&.edipi
  end

  # for PII reasons we don't send correlation ids over the wire
  # but JSON API requires an id with each resource
  #
  def id
    Digest::UUID.uuid_v5(last_name, email)
  end

  def identity
    @identity ||= IAMUserIdentity.find(uuid)
  end

  def sec_id
    identity.iam_sec_id || va_profile&.sec_id
  end

  def set_expire
    redis_namespace.expireat(REDIS_CONFIG[:iam_user][:namespace], expiration_timestamp)
  end
end
