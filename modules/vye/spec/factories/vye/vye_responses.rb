# frozen_string_literal: true

ERROR_RESPONSE_BODY = {
  'claimant_id' => nil,
  'delimiting_date' => nil,
  'enrollment_verifications' => nil,
  'verified_details' => nil,
  'payment_on_hold' => nil
}.freeze

FactoryBot.define do
  factory :claimant_lookup_response, class: 'Vye::DGIB::ClaimantLookupResponse' do
    status { 200 }
    claimant_id { 1 }

    initialize_with do
      # Mock the HTTP response object that the initializer expects
      http_response = double('http_response', body: { 'claimant_id' => claimant_id })
      new(status, http_response)
    end

    trait :not_found do
      status { 404 }
      initialize_with { new(404, nil) }
    end
  end

  factory :verification_record_response, class: 'Vye::DGIB::VerificationRecordResponse' do
    status { 200 }
    claimant_id { 1 }
    delimiting_date { '2024-01-15' }
    enrollment_verifications do
      [
        { 'school' => 'Test University', 'verified' => true },
        { 'school' => 'Another College', 'verified' => false }
      ]
    end
    verified_details do
      [
        { 'field' => 'enrollment_status', 'value' => 'enrolled' },
        { 'field' => 'credit_hours', 'value' => '12' }
      ]
    end
    payment_on_hold { false }

    initialize_with do
      http_response =
        double(
          'http_response',
          body: {
            'claimant_id' => claimant_id,
            'delimiting_date' => delimiting_date,
            'enrollment_verifications' => enrollment_verifications,
            'verified_details' => verified_details,
            'payment_on_hold' => payment_on_hold
          }
        )

      new(status, http_response)
    end

    trait :error_response do
      claimant_id { nil }
      delimiting_date { nil }
      enrollment_verifications { nil }
      verified_details { nil }
      payment_on_hold { nil }

      initialize_with do
        http_response = double('http_response', body: ERROR_RESPONSE_BODY)
        new(status, http_response)
      end
    end

    trait :no_content do
      error_response
      status { 204 }
    end

    trait :forbidden do
      error_response
      status { 403 }
    end

    trait :not_found do
      error_response
      status { 404 }
    end

    trait :unprocessable_entity do
      error_response
      status { 422 }
    end

    trait :service_unavailable do
      error_response
      status { nil }
    end

    trait :server_error do
      error_response
      status { 500 }
    end

    trait :with_payment_hold do
      payment_on_hold { true }
    end

    trait :no_verifications do
      enrollment_verifications { [] }
      verified_details { [] }
    end
  end

  factory :verify_claimant_response, class: 'Vye::DGIB::VerifyClaimantResponse' do
    status { 200 }
    claimant_id { 1 }
    delimiting_date { '2024-01-15' }
    verified_details do
      [
        { 'field' => 'enrollment_status', 'value' => 'enrolled' },
        { 'field' => 'credit_hours', 'value' => '12' }
      ]
    end
    payment_on_hold { false }

    initialize_with do
      http_response =
        double(
          'http_response',
          body: {
            'claimant_id' => claimant_id,
            'delimiting_date' => delimiting_date,
            'verified_details' => verified_details,
            'payment_on_hold' => payment_on_hold
          }
        )

      new(status, http_response)
    end

    trait :not_found do
      status { 404 }
      initialize_with { new(404, nil) }
    end

    trait :with_payment_hold do
      payment_on_hold { true }
    end

    trait :no_verified_details do
      verified_details { [] }
    end
  end

  factory :claimant_status_response, class: 'Vye::DGIB::ClaimantStatusResponse' do
    status { 200 }
    claimant_id { 1 }
    delimiting_date { '2024-01-15' }
    verified_details do
      [
        { 'field' => 'enrollment_status', 'value' => 'enrolled' }
      ]
    end
    payment_on_hold { false }

    initialize_with do
      http_response =
        double(
          'http_response',
          body: {
            'claimant_id' => claimant_id,
            'delimiting_date' => delimiting_date,
            'verified_details' => verified_details,
            'payment_on_hold' => payment_on_hold
          }
        )

      new(status, http_response)
    end

    trait :not_found do
      status { 404 }
      initialize_with { new(404, nil) }
    end
  end
end
