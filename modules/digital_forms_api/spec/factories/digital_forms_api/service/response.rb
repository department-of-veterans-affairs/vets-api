# frozen_string_literal: true

FactoryBot.define do
  factory :digital_forms_service_response, class: 'OpenStruct' do
    trait 'success' do
      reason_phrase { 'OK' }
      status { 200 }
      body do
        JSON.parse('{
          "submission": {
            "submissionId": "a1ba50e4-e689-4852-bec7-2a66519f0ed3",
            "claimId": "123456789"
          }
        }')
      end
    end
  end

  factory :digital_forms_service_error, class: 'Common::Client::Errors::ClientError' do
    trait 'error' do
      status { 503 }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "bip.framework.service.unavailable",
              "severity": "ERROR",
              "status": "503",
              "text": "Service unavailable."
            }
          ]
        }')
      end

      initialize_with { new('VEFSERR40009', status, body) }
    end
  end
end
