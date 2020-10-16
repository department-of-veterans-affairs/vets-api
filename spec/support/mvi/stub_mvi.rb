# frozen_string_literal: true

require 'mvi/responses/find_profile_response'

def stub_mvi(profile = nil)
  profile ||= build(:mvi_profile)
  # don't allow Mvi instances to be frozen during specs so that
  # response_from_redis_or_service can always be reset
  # (avoids WARNING: rspec-mocks was unable to restore the original... message)
  allow_any_instance_of(MPIData).to receive(:freeze) { self }
  allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.new(
      status: MVI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: profile
    )
  )
end

def stub_mvi_not_found
  allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
    MVI::Responses::FindProfileResponse.with_not_found(not_found_exception)
  )
end

def not_found_exception
  Common::Exceptions::BackendServiceException.new(
    'MVI_404',
    { source: 'MVI::Service' },
    404,
    'some error body'
  )
end

def server_error_exception
  Common::Exceptions::BackendServiceException.new(
    'MVI_503',
    { source: 'MVI::Service' },
    503,
    'some error body'
  )
end
