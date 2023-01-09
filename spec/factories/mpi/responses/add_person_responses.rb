# frozen_string_literal: true

FactoryBot.define do
  factory :add_person_response, class: 'MPI::Responses::AddPersonResponse' do
    skip_create

    status { MPI::Responses::AddPersonResponse::OK }
    parsed_codes { { transaction_id: SecureRandom.uuid } }
    error { nil }

    initialize_with do
      new(status: status,
          parsed_codes: parsed_codes,
          error: error)
    end
  end

  factory :add_person_server_error_response, class: 'MPI::Responses::AddPersonResponse' do
    skip_create

    status { MPI::Responses::AddPersonResponse::SERVER_ERROR }
    parsed_codes { nil }
    error { nil }

    initialize_with do
      new(status: status,
          parsed_codes: parsed_codes,
          error: error)
    end
  end
end
