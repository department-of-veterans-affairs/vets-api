# frozen_string_literal: true
require 'mvi/service_factory'
require 'mvi/responses/find_profile_response'

class Mvi
  attr_accessor :user, :mvi_response

  def initialize(user)
    @user = user
  end

  def status
    return MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:not_authorized] unless @user.loa3?
    mvi_response.status
  end

  def edipi
    return nil unless @user.loa3?
    profile&.edipi
  end

  def icn
    return nil unless @user.loa3?
    profile&.icn
  end

  def mhv_correlation_id
    return nil unless @user.loa3?
    profile&.mhv_correlation_id
  end

  def participant_id
    return nil unless @user.loa3?
    profile&.participant_id
  end

  def profile
    return nil unless @user.loa3?
    mvi_response&.profile
  end

  private

  def mvi_response
    @mvi_response ||= response_from_redis_or_service
  end

  def response_from_redis_or_service
    MVI::Responses::FindProfileResponse.find(@user.uuid) || query_and_cache_response
  end

  def query_and_cache_response
    response = mvi_service.find_profile(@user)
    response.cache_for_user(@user) if response.ok?
    response
  end

  def mvi_service
    @service ||= MVI::ServiceFactory.get_service(mock_service: Settings.mvi.mock)
  end
end
