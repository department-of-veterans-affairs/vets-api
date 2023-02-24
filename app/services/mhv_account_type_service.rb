# frozen_string_literal: true

require 'bb/client'

##
# Models logic pertaining to the verification and logging of MHV accounts
#
# @param user [User] the user object
#
class MHVAccountTypeService
  ELIGIBLE_DATA_CLASS_COUNT_TO_ACCOUNT_LEVEL = {
    32 => 'Premium',
    18 => 'Advanced',
    16 => 'Basic'
  }.freeze
  DEFAULT_ACCOUNT_LEVEL = 'Unknown'
  MHV_DOWN_MESSAGE = 'MHVAccountTypeService: could not fetch eligible data classes'
  UNEXPECTED_DATA_CLASS_COUNT_MESSAGE = 'MHVAccountTypeService: eligible data class mapping inconsistency'

  def initialize(user)
    @user = user
    @eligible_data_classes = fetch_eligible_data_classes if mhv_account?
  end

  attr_reader :user, :eligible_data_classes

  ##
  # Retrieve the MHV account type
  #
  # @return [NilClass] if the account is not an MHV account
  # @return [String] if the account is an MHV account, returns the account type
  #
  def mhv_account_type
    return nil unless mhv_account?

    if account_type_known?
      user.identity.mhv_account_type
    elsif eligible_data_classes.nil?
      'Error'
    else
      ELIGIBLE_DATA_CLASS_COUNT_TO_ACCOUNT_LEVEL.fetch(eligible_data_classes.size)
    end
  rescue KeyError
    log_account_type_heuristic(UNEXPECTED_DATA_CLASS_COUNT_MESSAGE)
    DEFAULT_ACCOUNT_LEVEL
  end

  ##
  # @return [Boolean] does the user have an MHV correlation ID?
  #
  def mhv_account?
    user.mhv_correlation_id.present?
  end

  ##
  # @return [Boolean] is the user MHV account type known?
  #
  def account_type_known?
    user.identity.mhv_account_type.present?
  end

  private

  def fetch_eligible_data_classes
    if cached_eligible_data_class
      json = Oj.load(cached_eligible_data_class)
      Common::Collection.new(::EligibleDataClass, **json.symbolize_keys).members.map(&:name)
    else
      bb_client = BB::Client.new(session: { user_id: @user.mhv_correlation_id })
      bb_client.authenticate
      bb_client.get_eligible_data_classes.members.map(&:name)
    end
  rescue => e
    log_account_type_heuristic(MHV_DOWN_MESSAGE, error_message: e.message)
    nil
  end

  def cached_eligible_data_class
    namespace = Redis::Namespace.new('common_collection', redis: $redis)
    cache_key = "#{user.mhv_correlation_id}:geteligibledataclass"
    namespace.get(cache_key)
  end

  def log_account_type_heuristic(message, extra_context = {})
    extra_context.merge!(
      uuid: user.uuid,
      mhv_correlation_id: user.mhv_correlation_id,
      eligible_data_classes: eligible_data_classes,
      authn_context: user.authn_context,
      va_patient: user.va_patient?,
      mhv_acct_type: user.identity.mhv_account_type
    )
    Rails.logger.warn("#{message}, #{extra_context}")
  end
end
