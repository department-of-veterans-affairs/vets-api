# frozen_string_literal: true

FactoryBot.define do
  factory :claims_api_evidence_waiver_submission, class: 'ClaimsApi::EvidenceWaiverSubmission' do
    cid { 'ghjhjklhjk' }
    id { SecureRandom.uuid }
    status { 'pending' }
    auth_headers { { va_eauth_pnid: '796378881' } }
  end

  trait :with_full_headers_jesse do
    auth_headers {
      {
        va_eauth_pnid: '796378881',
        va_eauth_birthdate: '1953-12-05',
        va_eauth_firstName: 'JESSE',
        va_eauth_lastName: 'GRAY'
      }
    }
  end

  trait :with_full_headers_tamara do
    auth_headers {
      {
        'va_eauth_pnid' => '600043201',
        'va_eauth_birthdate' => '1967-06-19',
        'va_eauth_firstName' => 'TAMARA',
        'va_eauth_lastName' => 'ELLIS'
      }
    }
  end
  trait :errored do
    status { 'errored' }
    vbms_error_message { 'An unknown error has occurred when uploading document' }
  end
end
