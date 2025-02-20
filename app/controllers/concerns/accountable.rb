# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern
  include SentryLogging

  def update_account_login_stats(login_type)
    return unless account_login_stats.present? && login_type.in?(SAML::User::LOGIN_TYPES)

    login_type = SAML::User::MHV_MAPPED_CSID if login_type == SAML::User::MHV_ORIGINAL_CSID

    account_login_stats.update!("#{login_type}_at" => Time.zone.now, current_verification: verification_level)
  rescue => e
    log_error(e, account_login_stats: 'update_failed')
  end

  private

  def account_login_stats
    @account_login_stats ||=
      if @current_user.account_id.present?
        AccountLoginStat.find_or_initialize_by(account_id: @current_user.account_id)
      else
        no_account_log_message
        nil
      end
  end

  def verification_level
    AccountLoginStat::VERIFICATION_LEVELS.detect do |str|
      @current_user.identity.authn_context&.gsub('/', '')&.scan(/#{str}/)&.present?
    end
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
      { idme_uuid: @current_user.idme_uuid,
        logingov_uuid: @current_user.logingov_uuid },
      account_login_stats: 'no_account_found'
    )
  end
end
