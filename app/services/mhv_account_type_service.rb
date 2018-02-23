# frozen_string_literal: true

require 'bb/client'
require 'sentry_logging'

class MhvAccountTypeService
  include SentryLogging
  PREMIUM_COUNT = 32
  ADVANCED_COUNT = 18

  def initialize(user)
    @user = user
  end

  attr_reader :user

  def probable_account_type
    return nil if @user.mhv_correlation_id.blank?
    if account_type_known?
      log_account_type_heuristic_once('MHV Account Type Known')
      @user.identity.mhv_account_type
    else
      log_account_type_heuristic_once('MHV Account Type Unknown')
      if eligible_data_classes.count == PREMIUM_COUNT
        'Premium'
      elsif eligible_data_classes.count == ADVANCED_COUNT
        'Advanced'
      else
        'Basic'
      end
    end
  end

  def account_type_known?
    @user.identity.mhv_account_type.present?
  end

  def eligible_data_classes
    return @eligible_data_classes if @eligible_data_classes
    bb_client = BB::Client.new(session: { user_id: @user.mhv_correlation_id })
    bb_client.authenticate
    @eligible_data_classes = bb_client.get_eligible_data_classes.members.map(&:name)
  rescue StandardError
    log_message_to_sentry('Could not fetch eligible data classes', :warn)
    []
  end

  def log_account_type_heuristic_once(message)
    return if @logged
    extra_context = {
      uuid: user.uuid,
      mhv_correlation_id: user.mhv_correlation_id,
      eligible_data_classes: eligible_data_classes,
      authn_context: user.authn_context,
      known_account_type: user.identity.mhv_account_type
    }
    tags = { sign_in_method: user.authn_context || 'idme' }

    log_message_to_sentry(message, :info, extra_context, tags)
    @logged = true
  end
end
