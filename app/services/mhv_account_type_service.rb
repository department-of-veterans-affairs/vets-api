# frozen_string_literal: true

require 'bb/client'
require 'sentry_logging'

class MhvAccountTypeService
  include SentryLogging
  ELIGIBLE_DATA_CLASS_COUNT_TO_ACCOUNT_LEVEL = {
    32 => 'Premium',
    18 => 'Advanced',
    16 => 'Basic'
  }.freeze
  DEFAULT_ACCOUNT_LEVEL = 'Unknown'
  MHV_DOWN_MESSAGE = 'MhvAccountTypeService: could not fetch eligible data classes'
  UNEXPECTED_DATA_CLASS_COUNT_MESSAGE = 'MhvAccountTypeService: eligible data class mapping inconsistency'

  def initialize(user)
    @user = user
    @eligible_data_classes = fetch_eligible_data_classes if mhv_account?
  end

  attr_reader :user, :eligible_data_classes

  def mhv_account_type
    return nil unless mhv_account?

    if account_type_known?
      @user.identity.mhv_account_type
    else
      ELIGIBLE_DATA_CLASS_COUNT_TO_ACCOUNT_LEVEL.fetch(eligible_data_classes.size)
    end
  rescue KeyError
    log_account_type_heuristic_once(UNEXPECTED_DATA_CLASS_COUNT_MESSAGE)
    DEFAULT_ACCOUNT_LEVEL
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
    log_account_type_heuristic_once(MHV_DOWN_MESSAGE)
    []
  end

  def log_account_type_heuristic_once(message)
    return if @logged
    extra_context = {
      uuid: user.uuid,
      mhv_correlation_id: user.mhv_correlation_id,
      eligible_data_classes: eligible_data_classes,
      authn_context: user.authn_context,
      va_patient: user.va_patient?,
      known_account_type: user.identity.mhv_account_type
    }
    tags = { sign_in_method: user.authn_context || 'idme' }
    log_message_to_sentry(message, :info, extra_context, tags)
    @logged = true
  end
end
