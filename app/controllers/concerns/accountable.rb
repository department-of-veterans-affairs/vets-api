# frozen_string_literal: true

module Accountable
  extend ActiveSupport::Concern

  # Creates a user's one Account record. By doing so, it initializes
  # a unique account#uuid for the user, through a callback on
  # Account.
  #
  def create_user_account
    return if @current_user&.cached_account&.uuid.present?
    return unless @current_user.uuid && Settings.account.enabled


    Account.find_or_create_by!(idme_uuid: @current_user.uuid) do |account|
      account.edipi = @current_user&.edipi
      account.icn   = @current_user&.icn
    end
  rescue StandardError => error
    log error
  end

  private

  def log(error)
    log_message_to_sentry(
      'Account Creation Error',
      :error,
      {
        error: error.inspect,
        idme_uuid: @current_user.uuid
      },
      account: 'cannot_create_unique_account_record'
    )
  end
end
