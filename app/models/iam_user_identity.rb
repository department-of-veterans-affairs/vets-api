# frozen_string_literal: true

# Subclasses the `UserIdentity` model. Adds a unique redis namespace for IAM user identities.
# Like the it's base model it acts as an adapter for the attributes from the IAMSSOeOAuth::Service's
# introspect endpoint.Adds IAM sourced versions of ICN, EDIPI, and SEC ID to pass to the IAMUser model.
#
class IAMUserIdentity < ::UserIdentity
  PREMIUM_LOAS = [2, 3].freeze
  UPGRADE_AUTH_TYPES = %w[DSL MHV].freeze

  redis_store REDIS_CONFIG[:iam_user_identity][:namespace]
  redis_ttl REDIS_CONFIG[:iam_user_identity][:each_ttl]
  redis_key :uuid

  attribute :expiration_timestamp, Integer
  attribute :iam_icn, String
  attribute :iam_edipi, String
  attribute :iam_sec_id, String
  attribute :iam_mhv_id, String

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
      iam_icn: iam_profile[:fediam_mviicn],
      iam_edipi: iam_profile[:fediam_do_dedipn_id],
      iam_sec_id: iam_profile[:fediamsecid],
      iam_mhv_id: valid_mhv_id(iam_profile[:fediam_mhv_ien]),
      last_name: iam_profile[:family_name],
      loa: { current: loa_level, highest: loa_level },
      middle_name: iam_profile[:middle_name]
    )

    identity.set_expire
    identity
  end

  def multifactor
    loa[:current]&.to_int == LOA::THREE
  end

  def set_expire
    redis_namespace.expireat(REDIS_CONFIG[:iam_user_identity][:namespace], expiration_timestamp)
  end

  # Users from IAM don't have a UUID like ID.me create one from the sec_id and iam_icn
  # @return [String] UUID that is unique to this user
  #
  def uuid
    Digest::UUID.uuid_v5(@iam_sec_id, @iam_icn)
  end

  # Return a single mhv id from a possible comma-separated list value attribute
  def self.valid_mhv_id(id_from_profile)
    # TODO: site login fails if multiple _different_ MHV IDs are present
    # Should this code be doing the same? Or at least logging a warning?
    # see lib/saml/user_attributes/ssoe.rb for example validation
    id_from_profile&.split(',')&.first
  end

  private_class_method :valid_mhv_id
end
