# frozen_string_literal: true
require 'mvi/service_factory'

class Mvi
  attr_accessor :user, :profile_response

  def initialize(user)
    @user = user
  end

  def va_profile
    @profile_response ||= fetch_from_redis_or_service
  end

  private

  def fetch_from_redis_or_service
    MviProfile.find(@user.uuid) || query_and_cache_profile
  end

  def query_and_cache_profile
    response = mvi_service.find_profile(@user)
    response.profile.save
    response.profile
  end

  def mvi_service
    @service ||= MVI::ServiceFactory.get_service(mock_service: Settings.mvi.mock)
  end
end
