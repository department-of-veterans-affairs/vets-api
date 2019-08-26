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
  rescue => error
    log error
  end

  private

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
