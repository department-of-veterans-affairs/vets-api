# frozen_string_literal: true

require 'mhv_ac/client'
require 'sentry_logging'

class MhvAccountsService
  include SentryLogging

  STATSD_ACCOUNT_EXISTED_KEY = 'mhv.account.existed'
  STATSD_ACCOUNT_CREATION_KEY = 'mhv.account.creation'
  STATSD_ACCOUNT_UPGRADE_KEY = 'mhv.account.upgrade'

  ADDRESS_ATTRS = %w[street city state postal_code country].freeze

  def initialize(mhv_account)
    @mhv_account = mhv_account
    @user = mhv_account.user
  end

  attr_accessor :mhv_account, :user

  def create
    if mhv_account.creatable?
      client_response = mhv_ac_client.post_register(params_for_registration)
      if client_response[:api_completion_status] == 'Successful'
        StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.success")
        mhv_id = client_response[:correlation_id].to_s
        mhv_account.registered_at = Time.current
        mhv_account.mhv_correlation_id = mhv_id
        user.va_profile.mhv_ids = [mhv_id] + user.va_profile.mhv_ids
        user.va_profile.active_mhv_ids = [mhv_id] + user.va_profile.active_mhv_ids
        user.recache
        mhv_account.register!
      end
    end
  rescue => e
    log_warning(type: :create, exception: e, extra: params_for_registration.slice(:icn))
    StatsD.increment("#{STATSD_ACCOUNT_CREATION_KEY}.failure")
    # we no longer persist failure states
    mhv_account.fail_register
    raise e
  end

  def upgrade
    if mhv_account.upgradable?
      client_response = mhv_ac_client.post_upgrade(params_for_upgrade)
      if client_response[:status] == 'success'
        StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.success")
        mhv_account.upgraded_at = Time.current
        Common::Collection.bust("#{mhv_account.mhv_correlation_id}:geteligibledataclass")
        mhv_account.upgrade!
      end
    end
  rescue => e
    log_warning(type: :upgrade, exception: e, extra: params_for_upgrade)
    StatsD.increment("#{STATSD_ACCOUNT_UPGRADE_KEY}.failure")
    # we no longer persist failure states
    mhv_account.fail_upgrade
    raise e
  end

  private

  def address_params
    if user.va_profile&.address.present?
      {
        address1: user.va_profile.address.street,
        city: user.va_profile.address.city,
        state: user.va_profile.address.state,
        zip: user.va_profile.address.postal_code,
        country: user.va_profile.address.country
      }
    else
      {}
    end
  end

  def params_for_registration
    {
      icn: user.icn,
      is_patient: user.va_patient?,
      is_veteran: user.veteran?,
      province: nil, # TODO: We need to determine if this is something that could actually happen (non USA)
      email: user.email,
      home_phone: user.va_profile&.home_phone,
      sign_in_partners: 'VETS.GOV',
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

  def current_account_type
    @current_account_type ||= MhvAccountTypeService.new(user).probable_account_type
  end
end
