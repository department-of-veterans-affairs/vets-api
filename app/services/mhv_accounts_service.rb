# frozen_string_literal: true

require 'mhv_ac/client'
require 'sentry_logging'

##
# Models MHV Account creation and upgrade logic processes
#
# @param mhv_account [MHVAccount] the user's MHVAccount object from DB
# @param user [User] the user's User object from Redis cache
#
class MHVAccountsService
  include SentryLogging

  STATSD_ACCOUNT_EXISTED_KEY = 'mhv.account.existed'
  STATSD_ACCOUNT_CREATION_KEY = 'mhv.account.creation'
  STATSD_ACCOUNT_UPGRADE_KEY = 'mhv.account.upgrade'

  ADDRESS_ATTRS = %w[street city state postal_code country].freeze

  def initialize(mhv_account, user)
    @mhv_account = mhv_account
    @mhv_account.user = user
  end

  attr_accessor :mhv_account

  delegate :user, to: :mhv_account

  ##
  # Create a new MHV account if possible, else rescue and log failures before raising
  #
  # @raise [StandardError] if the account creation fails
  # @return [TrueClass] if the account creation succeeds
  #
  def create
    if mhv_account.creatable?
      client_response = mhv_ac_client.post_register(params_for_registration)
      if client_response[:api_completion_status] == 'Successful'
        StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.success")
        mhv_id = client_response[:correlation_id].to_s
        mhv_account.registered_at = Time.current
        mhv_account.mhv_correlation_id = mhv_id
        mhv_account.register!
        user.set_mhv_ids(mhv_id)
      end
    end
  rescue => e
    log_warning(type: :create, exception: e, extra: params_for_registration.slice(:icn))
    StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.failure")
    mhv_account.fail_register!
    raise e
  end

  ##
  # Upgrade an MHV account if possible, else rescue and log failures before raising
  #
  # @raise [StandardError] if the upgrade process fails
  # @return [TrueClass] if the upgrade is successful
  #
  def upgrade
    if mhv_account.upgradable?
      handle_upgrade!
    elsif mhv_account.already_premium? && mhv_account.registered_at?
      # we have historic evidence that some accounts we registered became 'Premium' on their own,
      # so we want to track it similarly as before.
      mhv_account.upgrade!
    else
      StatsD.increment(STATSD_ACCOUNT_EXISTED_KEY.to_s)
      mhv_account.existing_premium! # without updating the timestamp since account was not created at vets.gov
    end
  rescue => e
    if mhv_account.account_level == 'Error'
      log_message_to_sentry('Possible Race Condition In MHV Upgrade', :warn, extra_context: mhv_account.attributes)
    end
    log_warning(type: :upgrade, exception: e, extra: params_for_upgrade)
    StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.failure")
    mhv_account.fail_upgrade!
    raise e
  end

  private

  def handle_upgrade!
    client_response = mhv_ac_client.post_upgrade(params_for_upgrade)
    if client_response[:status] == 'success'
      StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.success")
      mhv_account.upgraded_at = Time.current
      mhv_account.upgrade!
      Common::Collection.bust("#{mhv_account.mhv_correlation_id}:geteligibledataclass")
    end
  end

  def address_params
    {
      address1: user.address[:street],
      city: user.address[:city],
      state: user.address[:state],
      zip: user.address[:postal_code],
      country: user.address[:country]
    }
  end

  def params_for_registration
    {
      icn: user.icn,
      is_patient: user.va_patient?,
      is_veteran: user.veteran?,
      province: nil, # TODO: We need to determine if this is something that could actually happen (non USA)
      email: user.email,
      home_phone: user.home_phone,
      sign_in_partners: 'VA.GOV',
      terms_version: mhv_account.terms_and_conditions_accepted.terms_and_conditions.version,
      terms_accepted_date: mhv_account.terms_and_conditions_accepted.created_at
    }.merge!(address_params)
  end

  def params_for_upgrade
    {
      user_id: user.mhv_correlation_id,
      form_signed_date_time: mhv_account.terms_and_conditions_accepted.created_at,
      terms_version: mhv_account.terms_and_conditions_accepted.terms_and_conditions.version
    }
  end

  def log_warning(type:, exception:, extra: {})
    message = type == :upgrade ? 'MHV Upgrade Failed!' : 'MHV Create Failed!'
    extra_content = if exception.is_a?(Common::Exceptions::BackendServiceException)
                      extra.merge(exception_type: 'BackendServiceException', body: exception.original_body)
                    else
                      extra.merge(exception_type: exception.message)
                    end
    log_message_to_sentry(message, :warn, extra_content)
  end

  def mhv_ac_client
    @mhv_ac_client ||= MHVAC::Client.new
  end
end
