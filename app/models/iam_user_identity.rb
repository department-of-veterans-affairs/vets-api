# frozen_string_literal: true

require 'sentry_logging'

# Subclasses the `UserIdentity` model. Adds a unique redis namespace for IAM user identities.
# Like the it's base model it acts as an adapter for the attributes from the IAMSSOeOAuth::Service's
# introspect endpoint.Adds IAM sourced versions of ICN, EDIPI, and SEC ID to pass to the IAMUser model.
#
class IAMUserIdentity < UserIdentity
  extend SentryLogging
  extend Identity::Parsers::GCIdsHelper

  PREMIUM_LOAS = [2, 3].freeze
  UPGRADE_AUTH_TYPES = %w[DSL MHV].freeze
  MULTIFACTOR_AUTH_TYPES = %w[IDME LOGINGOV].freeze

  IAM_NAMESPACE = 'eb7b724e-bd8c-4dc3-b5fa-30f335938b42'

  redis_store REDIS_CONFIG[:iam_user_identity][:namespace]
  redis_ttl REDIS_CONFIG[:iam_user_identity][:each_ttl]
  redis_key :uuid

  attribute :expiration_timestamp, Integer
  attribute :iam_edipi, String
  attribute :iam_sec_id, String
  attribute :iam_mhv_id, String

  # MPI::Service uses 'mhv_icn' to query by icn rather than less accurate user traits
  alias mhv_icn icn

  # Builds an identity instance from the profile returned in the IAM introspect response
  #
  # @param iam_profile [Hash] the profile of the user, as they are known to the IAM SSOe service.
  # @return [IAMUserIdentity] an instance of this class
  #
  def self.build_from_iam_profile(iam_profile)
    loa_level = iam_profile[:fediamassur_level].to_i
    iam_auth_n_type = iam_profile[:fediamauth_n_type]
    loa_level = 3 if UPGRADE_AUTH_TYPES.include?(iam_auth_n_type) && PREMIUM_LOAS.include?(loa_level)

    identity = new(
      email: iam_profile[:email],
      expiration_timestamp: iam_profile[:exp],
      first_name: iam_profile[:given_name],
      icn: iam_profile[:fediam_mviicn],
      iam_edipi: sanitize_edipi(iam_profile[:fediam_do_dedipn_id]),
      iam_sec_id: iam_profile[:fediamsecid],
      iam_mhv_id: valid_mhv_id(iam_profile[:fediam_mhv_ien]),
      last_name: iam_profile[:family_name],
      loa: { current: loa_level, highest: loa_level },
      middle_name: iam_profile[:middle_name],
      multifactor: multifactor?(loa_level, iam_auth_n_type),
      sign_in: { service_name: "oauth_#{iam_auth_n_type}", account_type: iam_profile[:fediamassur_level],
                 auth_broker: SAML::URLService::BROKER_CODE, client_id: SAML::URLService::MOBILE_CLIENT_ID }
    )

    identity.set_expire
    identity
  end

  def self.multifactor?(loa_level, auth_type)
    loa_level == LOA::THREE && MULTIFACTOR_AUTH_TYPES.include?(auth_type)
  end

  def set_expire
    redis_namespace.expireat(REDIS_CONFIG[:iam_user_identity][:namespace], expiration_timestamp)
  end

  # Users from IAM don't have a UUID like ID.me, instead we create one from the sec_id and iam_icn.
  # It's used for JSON API object serialization, caching (no longer than a session), and debugging.
  # The hashed value is not reversible and does not reference any external system or database.
  # @return [String] UUID that is unique to this user
  #
  def uuid
    Digest::UUID.uuid_v5(IAM_NAMESPACE, @icn)
  end

  # Return a single mhv id from a possible comma-separated list value attribute
  def self.valid_mhv_id(id_from_profile)
    # TODO: For now, log instances of duplicate MHV ID.
    # See issue #19971 for consideration of whether to reject access
    # to features using this identifier if this happens.
    mhv_ids = (id_from_profile == 'NOT_FOUND' ? nil : id_from_profile)
    mhv_ids = mhv_ids&.split(',')&.uniq
    if mhv_ids&.size.to_i > 1
      log_message_to_sentry('OAuth: Multiple MHV IDs present', :warn, { mhv_ien: id_from_profile })
    end
    mhv_ids&.first
  end

  private_class_method :valid_mhv_id
end
