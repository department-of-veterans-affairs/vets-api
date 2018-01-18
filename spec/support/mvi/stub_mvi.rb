# frozen_string_literal: true

def stub_mvi(profile = nil)
  profile ||= build(:mvi_profile)
  allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.new(
      status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: profile
    )
  )
end

def stub_mvi_not_found
  allow_any_instance_of(Mvi).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.with_not_found
  )
end
