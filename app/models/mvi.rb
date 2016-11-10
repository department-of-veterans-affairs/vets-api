# frozen_string_literal: true
require 'digest'
require 'common/models/redis_store'

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
    mvi = Mvi.new(uuid: user.uuid)
    mvi.user = user
    mvi
  end

  def query
    cached = Mvi.find(@user.uuid)
    return cached&.response if cached
    message = create_message
    query_and_cache(message)
  end

  private

  def mvi_service
    @service ||= MVI::ServiceFactory.get_service(mock_service: ENV['MOCK_MVI_SERVICE'])
  end

  def create_message
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

  def query_and_cache(message)
    self.response = mvi_service.find_candidate(message)
    self.response[:status] = MVI_RESPONSE_STATUS[:ok]
    self.save
    response
  rescue MVI::RecordNotFound
    Rails.logger.error "MVI record not found for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:not_found] }
  rescue MVI::HTTPError => e
    Rails.logger.error "MVI HTTP error code: #{e.code} for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:server_error] }
  rescue MVI::ServiceError => e
    Rails.logger.error "MVI service error: #{e.message} for user: #{@user.uuid}"
    { status: MVI_RESPONSE_STATUS[:server_error] }
  end
end
