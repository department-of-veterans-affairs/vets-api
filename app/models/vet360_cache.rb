# frozen_string_literal: true

require 'common/models/redis_store'
require 'common/models/concerns/cache_aside'

# Facade for Vet360. User model delegates MVI correlation id and VA profile (golden record) methods to this class.
# When a profile is requested from one of the delegates it is returned from either a cached response in Redis
# or from the MVI SOAP service.
#
class Vet360Cache < Common::RedisStore
  include Common::CacheAside

  # TODO - what should this be?
  redis_config_key :mvi_profile_response

  # @return [User] the user to query MVI for.
  #
  attr_accessor :user

  # Creates a new Mvi instance for a user.
  #
  # @param user [User] the user to query MVI for
  # @return [Mvi] an instance of this class
  #
  def self.for_user(user)
    vet360 = Vet360Cache.new
    vet360.user = user
    vet360
  end

  # The profile returned from the MVI service. Either returned from cached response in Redis or the MVI service.
  #
  # @return [MVI::Models::MviProfile] patient 'golden record' data from MVI
  def profile
    return nil unless @user.loa3?
    mvi_response&.profile
  end

  # @return [MVI::Responses::FindProfileResponse] the response returned from MVI
  def vet360_response
    @vet360_response ||= response_from_redis_or_service
  end

  private

  # TODO - thinking we want to use a diff key than uuid?
  def response_from_redis_or_service
    do_cached_with(key: "vet360-#{@user.uuid}") do
      vet360_service.get_person
    end
  end

  def vet360_service
    @service ||= Vet360::ContactInformation::Service.new(@user)
  end
end
