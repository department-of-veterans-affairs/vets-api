# frozen_string_literal: true

require 'mpi/errors/errors'

FactoryBot.define do
  factory :find_profile_response, class: 'MPI::Responses::FindProfileResponse' do
    skip_create

    status { MPI::Responses::FindProfileResponse::OK }
    profile { create(:mpi_profile) }
    error { nil }

    initialize_with do
      new(status:,
          profile:,
          error:)
    end
  end

  factory :find_profile_not_found_response, class: 'MPI::Responses::FindProfileResponse' do
    skip_create

    status { MPI::Responses::FindProfileResponse::NOT_FOUND }
    profile { nil }
    error { MPI::Errors::RecordNotFound.new('Record not found') }

    initialize_with do
      new(status:,
          profile:,
          error:)
    end
  end

  factory :find_profile_server_error_response, class: 'MPI::Responses::FindProfileResponse' do
    skip_create

    status { MPI::Responses::FindProfileResponse::SERVER_ERROR }
    profile { nil }
    error { MPI::Errors::FailedRequestError.new('Server error') }

    initialize_with do
      new(status:,
          profile:,
          error:)
    end
  end
end
