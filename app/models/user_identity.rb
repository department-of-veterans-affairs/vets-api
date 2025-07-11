# frozen_string_literal: true

require 'common/redis_model'

# Stores attributes used to identify a user. Serves as a set of inputs to an MVI lookup. Also serves
# as the receiver of identity attributes received from alternative sources during the SSO flow.
class UserIdentity < Common::RedisModel
  redis_store REDIS_CONFIG[:user_identity_store][:namespace]
  redis_ttl REDIS_CONFIG[:user_identity_store][:each_ttl]
  redis_key :uuid

  # identity attributes
  attribute :uuid, :string
  attribute :email, :string
  attribute :first_name, :string
  attribute :middle_name, :string
  attribute :last_name, :string
  attribute :gender, :string
  attribute :birth_date, :string
  attribute :icn, :string
  attribute :ssn, :string
  attribute :loa, :string
  attribute :multifactor, :boolean # used by F/E to decision on whether or not to prompt user to add MFA
  attribute :authn_context, :string # used by F/E to handle various identity related complexities pending refactor
  attribute :idme_uuid, :string
  attribute :logingov_uuid, :string
  attribute :verified_at, :string # Login.gov IAL2 verification timestamp
  attribute :sec_id, :string
  attribute :mhv_icn, :string # only needed by B/E not serialized in user_serializer
  attribute :mhv_credential_uuid, :string
  attribute :mhv_account_type, :string # this is only available for MHV sign-in users
  attribute :edipi, :string # this is only available for dslogon users
  attribute :sign_in, :string # original sign_in (see sso_service#mergable_identity_attributes) 
  # (RedisStore note: use string for sign_in and serializing manually)
  attribute :icn_with_aaid, :string
  attribute :search_token, :string

  validates :uuid, presence: true
  validates :loa, presence: true
  validate :loa_highest_present

  def sign_in
    @sign_in ||= JSON.parse(super || '{}')
  end

  def sign_in=(value)
    super(value.to_json)
    @sign_in = value
  end

  def loa
    @loa ||= JSON.parse(super || '{}')
  end

  def loa=(value)
    super(value.to_json)
    @loa = value
  end

  # LOA3 no longer just means ID.me FICAM LOA3.
  # It could also be DSLogon or MHV Premium users.
  # It could also be DSLogon or MHV NON PREMIUM users who have done ID.me FICAM LOA3.
  # Additionally, LOA3 does not automatically mean user has opted to have MFA.
  def loa3?
    loa && loa[:current].to_i == LOA::THREE
  end

  with_options if: :loa3? do
    validates :ssn, format: /\A\d{9}\z/, allow_blank: true
    validates :gender, format: /\A(M|F)\z/, allow_blank: true
  end

  private

  def loa_highest_present
    errors.add(:loa, 'loa[:highest] is not present!') if loa[:highest].blank?
  end
end
