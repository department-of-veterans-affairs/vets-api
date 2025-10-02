# frozen_string_literal: true

FactoryBot.define do
  # @see https://fwdproxy-prod.vfs.va.gov:4469/api/v1/rest/swagger-ui.html#/File/upload
  factory :claims_evidence_service_files_response, class: 'OpenStruct' do
    trait 'success' do
      reason_phrase { 'OK' }
      status { 200 }
      body do
        JSON.parse('{
          "uuid": "c30626c9-954d-4dd1-9f70-1e38756d9d97",
          "currentVersionUuid": "c30626c9-954d-4dd1-9f70-1e38756d9d98",
          "conversionInformation": {
            "preprocessed": {
              "versionUuid": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              "mimeType": "string",
              "uploadedDateTime": "string"
            },
            "converted": {
              "versionUuid": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
              "mimeType": "string",
              "uploadedDateTime": "string"
            }
          }
        }')
      end
    end
  end

  factory :claims_evidence_service_files_error, class: 'Common::Client::Errors::ClientError' do
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
              "text": "No JWT Token in Header.",
              "httpStatus": "UNAUTHORIZED"
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
          "uuid": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
          "code": "VEFSERR40009",
          "message": "JWT provided does not contain expected claims, or contains invalid claim value(s)."
        }')
      end

      initialize_with { new('VEFSERR40009', status, body) }
    end
  end
end
