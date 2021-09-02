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
    log e
  end

  def update_account_login_stats
    return unless login_stats.present? && login_type.in?(AccountLoginStat::LOGIN_TYPES)

    login_stats.update("#{login_type}_at" => Time.zone.now)
  end

  private

  def login_stats
    @login_stats ||=
      @current_user.account.present? &&
      AccountLoginStat.find_or_initialize_by(account_id: @current_user.account.id)
  end

  def login_type
    @login_type ||= @current_user.identity.sign_in[:service_name]
  end

  def log(error)
    log_exception_to_sentry(
      error,
      {
        error: error.inspect,
        idme_uuid: @current_user.uuid
      },
      account: 'cannot_create_unique_account_record'
    )
  end
end
