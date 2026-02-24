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
    trait 'unauthorized' do
      status { 401 }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "UNAUTHORIZED",
              "severity": "ERROR",
              "status": "401",
              "text": "No JWT Token in Header."
            }
          ]
        }')
      end

      initialize_with { new('UNAUTHORIZED', status, body) }
    end

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

    trait 'not_found' do
      status { 404 }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "FORM_NOT_FOUND",
              "severity": "ERROR",
              "status": "404",
              "text": "Form not found."
            }
          ]
        }')
      end

      initialize_with { new('FORM_NOT_FOUND', status, body) }
    end

    trait 'access_denied' do
      status { 403 }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "ACCESS_DENIED",
              "severity": "ERROR",
              "status": "403",
              "text": "Access denied."
            }
          ]
        }')
      end

      initialize_with { new('ACCESS_DENIED', status, body) }
    end

    trait 'server_error' do
      status { 500 }
      body do
        JSON.parse('{
          "messages": [
            {
              "timestamp": "2024-05-20T15:53:29.389",
              "key": "INTERNAL_SERVER_ERROR",
              "severity": "ERROR",
              "status": "500",
              "text": "Internal server error."
            }
          ]
        }')
      end

      initialize_with { new('INTERNAL_SERVER_ERROR', status, body) }
    end
  end
end
