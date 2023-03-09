# frozen_string_literal: true

require 'digest'
require 'active_support/core_ext/digest/uuid'
require 'common/client/errors'

# Subclasses the `User` model. Adds a unique redis namespace for IAM users.
# Adds IAM sourced versions of ICN, EDIPI, and SEC ID and methods to use them
# or hit MPI via the mpi_profile.
#
class IAMUser < ::User
  redis_store REDIS_CONFIG[:iam_user][:namespace]
  redis_ttl REDIS_CONFIG[:iam_user][:each_ttl]
  redis_key :uuid

  attribute :expiration_timestamp, Integer
  attribute :iam_edipi, String
  attribute :iam_sec_id, String
  attribute :iam_mhv_id, String

  alias mhv_correlation_id iam_mhv_id

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

  # Return the uuid as the id for the user. This id is generated
  # within the IAMUserIdentity class.
  # @return [String] UUID that is unique to this user
  #
  def id
    uuid
  end

  def common_name
    "#{identity.first_name} #{identity.last_name}"
  end

  def identity
    @identity ||= IAMUserIdentity.find(uuid)
  end

  def sec_id
    identity.iam_sec_id || sec_id
  end

  def mhv_account_type
    MHVAccountTypeService.new(self).mhv_account_type
  end

  # This is not the correct way of determining VA patient status,
  # but it works for authorizing access for existing MHV premium users
  # If we are going to enable account creation/upgrade, then we'll need
  # to  derive the list of facilities from the IAM introspection payload.
  def va_patient?
    mhv_correlation_id.present?
  end

  def set_expire
    redis_namespace.expireat(REDIS_CONFIG[:iam_user][:namespace], expiration_timestamp)
  end

  def vet360_contact_info
    super
  rescue Faraday::ResourceNotFound
    raise Common::Exceptions::RecordNotFound, vet360_id
  rescue Common::Client::Errors::ClientError
    raise Common::Exceptions::BadGateway.new(id: vet360_id)
  end
end
