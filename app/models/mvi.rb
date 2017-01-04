# frozen_string_literal: true
require 'common/models/redis_store'
require 'mvi/service_factory'

class Mvi < Common::RedisStore
  redis_store REDIS_CONFIG['mvi_store']['namespace']
  redis_ttl REDIS_CONFIG['mvi_store']['each_ttl']
  redis_key :uuid

  MVI_RESPONSE_STATUS = {
    ok: 'OK',
    not_found: 'NOT_FOUND',
    server_error: 'SERVER_ERROR'
  }.freeze

  attr_accessor :user
  attribute :uuid
  attribute :response

  def self.from_user(user)
    mvi = Mvi.find_or_build(user.uuid)
    mvi.user = user
    mvi
  end

  def edipi
    select_source_id(:edipi)
  end

  def icn
    select_source_id(:icn)
  end

  def participant_id
    select_source_id(:vba_corp_id)
  end

  def mhv_correlation_id
    mhv_correlation_ids&.first
  end

  def va_profile
    return { status: 'NOT_AUTHORIZED' } unless @user.loa3?
    response = mvi_response
    return { status: 'SERVER_ERROR' } unless response
    return response unless response[:status] == MVI_RESPONSE_STATUS[:ok]
    {
      status: response[:status],
      birth_date: response[:birth_date],
      family_name: response[:family_name],
      gender: response[:gender],
      given_names: response[:given_names]
    }
  end

  private

  def mhv_correlation_ids
    return nil unless mvi_response
    ids = mvi_response&.dig(:mhv_ids)
    ids = [] unless ids
    ids.map { |mhv_id| mhv_id.split('^')&.first }.compact
  end

  def select_source_id(correlation_id)
    return nil unless mvi_response&.dig(correlation_id)
    mvi_response[correlation_id].split('^')&.first
  end

  def mvi_response
    return nil unless @user.loa3?
    @memoized_response ||= response || query_and_cache_response
  end

  def mvi_service
    @service ||= MVI::ServiceFactory.get_service(mock_service: ENV['MOCK_MVI_SERVICE'])
  end

  def create_message
    raise Common::Exceptions::ValidationErrors, @user unless @user.valid?(:loa3_user)
    given_names = [@user.first_name]
    given_names.push @user.middle_name unless @user.middle_name.nil?
    MVI::Messages::FindCandidateMessage.new(
      given_names,
      @user.last_name,
      @user.birth_date,
      @user.ssn,
      @user.gender
    )
  end

  def query_and_cache_response
    query_response = mvi_service.find_candidate(create_message)
    query_response[:status] = MVI_RESPONSE_STATUS[:ok]
    self.response = query_response
    save
    response
  rescue SOAP::Errors::RecordNotFound
    Rails.logger.error "MVI record not found for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:not_found] }
  rescue SOAP::Errors::HTTPError => e
    Rails.logger.error "MVI HTTP error code: #{e.code} for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:server_error] }
  rescue SOAP::Errors::ServiceError => e
    Rails.logger.error "MVI service error: #{e.message} for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:server_error] }
  end
end
