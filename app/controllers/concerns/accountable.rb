# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern
  include SentryLogging

  # Creates a user's one Account record. By doing so, it initializes
  # a unique account#uuid for the user, through a callback on
  # Account.
  #
  def create_user_account
    Account.cache_or_create_by! @current_user
  rescue => e
    log_error(e, account: 'cannot_create_unique_account_record')
  end

  def update_account_login_stats
    return unless account_login_stats.present? && login_type.in?(AccountLoginStat::LOGIN_TYPES)

    account_login_stats.update!("#{login_type}_at" => Time.zone.now)
  rescue => e
    log_error(e, account_login_stats: 'update_failed')
  end

  private

  def account_login_stats
    @account_login_stats ||=
      if @current_user.account.present?
        AccountLoginStat.find_or_initialize_by(account_id: @current_user.account.id)
      else
        no_account_log_message
        nil
      end
  end

  def login_type
    @login_type ||= @current_user.identity.sign_in[:service_name]
  end

  def log_error(error, tag_hash)
    log_exception_to_sentry(
      error,
      {
        error: error.inspect,
        idme_uuid: @current_user.idme_uuid,
        logingov_uuid: @current_user.logingov_uuid
      },
      tag_hash
    )
  end

  def no_account_log_message
    log_message_to_sentry(
      'No account found for user',
      :warn,
      { idme_uuid: @current_user.uuid },
      account_login_stats: 'no_account_found'
    )
  end
end
