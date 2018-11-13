# frozen_string_literal: true

def stub_mvi(profile = nil)
  Mvi.memory_cache.clear
  profile ||= build(:mvi_profile)
  # don't allow Mvi instances to be frozen during specs so that
  # response_from_redis_or_service can always be reset
  # (avoids WARNING: rspec-mocks was unable to restore the original... message)
  allow_any_instance_of(Mvi).to receive(:freeze) { self }
  allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.new(
      status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: profile
    )
  )
end

def stub_mvi_not_found
  Mvi.memory_cache.clear
  allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.with_not_found
  )
end
