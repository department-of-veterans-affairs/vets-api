# frozen_string_literal: true

def stub_mpi(profile = nil)
  profile ||= build(:mpi_profile)
  # don't allow MPIData instances to be frozen during specs so that
  # response_from_redis_or_service can always be reset
  # (avoids WARNING: rspec-mocks was unable to restore the original... message)
  allow_any_instance_of(MPIData).to receive(:freeze) { self }
  allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
    MPI::Responses::FindProfileResponse.new(
      status: MPI::Responses::FindProfileResponse::RESPONSE_STATUS[:ok],
      profile: profile
    )
  )
end

def stub_mpi_not_found
  allow_any_instance_of(MPIData).to receive(:response_from_redis_or_service).and_return(
    MPI::Responses::FindProfileResponse.with_not_found(not_found_exception)
  )
end

def not_found_exception
  Common::Exceptions::BackendServiceException.new(
    'MVI_404',
    { source: 'MPI::Service' },
    404,
    'some error body'
  )
end

def server_error_exception
  Common::Exceptions::BackendServiceException.new(
    'MVI_503',
    { source: 'MPI::Service' },
    503,
    'some error body'
  )
end
