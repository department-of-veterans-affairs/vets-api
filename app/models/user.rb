# frozen_string_literal: true
class User < RedisStore
  NAMESPACE = REDIS_CONFIG['user_store']['namespace']
  REDIS_STORE = Redis::Namespace.new(NAMESPACE, redis: Redis.current)
  DEFAULT_TTL = REDIS_CONFIG['user_store']['each_ttl']

  # id.me attributes
  attribute :uuid
  attribute :email
  attribute :first_name
  attribute :last_name
  attribute :zip

  # vaafi attributes
  attribute :edipi
  attribute :issue_instant
  attribute :participant_id
  attribute :ssn

  # Add additional MVI attributes
  alias redis_key uuid

  validates :uuid, presence: true
  validates :email, presence: true

  def self.sample_claimant
    User.new(
      first_name: 'Jane',
      last_name: 'Doe',
      issue_instant: '2015-04-17T14:52:48Z',
      edipi: '1105051936',
      participant_id: '123456789'
    )
  end

  def claims
    Claim.fetch_all(vaafi_headers)
  end

  def request_claim_decision(claim_id)
    Claim.request_decision(vaafi_headers, claim_id)
  end

  private

  def vaafi_headers
    {
      # Always the same
      'va_eauth_csid' => 'DSLogon',
      'va_eauth_authenticationmethod' => 'DSLogon',
      'va_eauth_assurancelevel' => '2',
      'va_eauth_pnidtype' => 'SSN',
      # Vary by user
      'va_eauth_firstName' => @first_name,
      'va_eauth_lastName' => @last_name,
      'va_eauth_issueinstant' => @issue_instant,
      'va_eauth_dodedipnid' => @edipi,
      'va_eauth_pid' => @participant_id,
      'va_eauth_pnid' => @ssn
    }
  end
end
