# frozen_string_literal: true

require 'bb/client'
require 'sentry_logging'

class MhvAccountTypeService
  include SentryLogging
  PREMIUM_COUNT = 32
  ADVANCED_COUNT = 18
  ERROR_MESSAGE = 'MhvAccountTypeService: Could not fetch eligible data classes'
  KNOWN_MESSAGE = 'MhvAccountTypeService: Known'
  UNKNOWN_MESSAGE = KNOWN_MESSAGE = 'MhvAccountTypeService: Unknown'

  def initialize(user)
    @user = user
    @eligible_data_classes = fetch_eligible_data_classes if mhv_account?
  end

  attr_reader :user, :eligible_data_classes

  def probable_account_type
    return nil unless mhv_account?
    log_account_type_heuristic_once
    if account_type_known?
      @user.identity.mhv_account_type
    elsif eligible_data_classes.count == PREMIUM_COUNT
      'Premium'
    elsif eligible_data_classes.count == ADVANCED_COUNT
      'Advanced'
    else
      'Basic'
    end
  end

  def mhv_account?
    @user.mhv_correlation_id.present?
  end

  def account_type_known?
    @user.identity.mhv_account_type.present?
  end

  private

  def fetch_eligible_data_classes
    bb_client = BB::Client.new(session: { user_id: @user.mhv_correlation_id })
    bb_client.authenticate
    bb_client.get_eligible_data_classes.members.map(&:name)
  rescue StandardError
    @error = ERROR_MESSAGE
    []
  end

  def log_account_type_heuristic_once
    return nil if @logged
    extra_context = {
      uuid: user.uuid,
      mhv_correlation_id: user.mhv_correlation_id,
      eligible_data_classes: eligible_data_classes,
      authn_context: user.authn_context,
      known_account_type: user.identity.mhv_account_type
    }
    tags = { sign_in_method: user.authn_context || 'idme' }
    log_message_to_sentry(logging_message, :info, extra_context, tags)
    @logged = true
  end

  def logging_message
    @error_message || account_type_known? ? KNOWN_MESSAGE : UNKNOWN_MESSAGE
  end
end
