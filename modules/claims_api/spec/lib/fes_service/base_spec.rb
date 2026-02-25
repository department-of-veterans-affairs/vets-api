# frozen_string_literal: true

require 'rails_helper'
require 'fes_service/base'

describe ClaimsApi::FesService::Base do
  let(:service) { described_class.new }
  let(:claim) do
    double('claim',
           id: 123,
           transaction_id: 'abc-123-def',
           auth_headers: { 'va_eauth_pid' => '600043201' },
           veteran: double('veteran', participant_id: '600043201'),
           claimant_participant_id: nil)
  end
  let(:invalid_form_data) do
    {
      form526: {
        'veteran' => { 'firstName' => 'John', 'lastName' => 'Doe' },
        'disabilities' => [{ 'name' => 'Hearing Loss' }]
      }
    }
  end
  let(:fes_auth_headers) do
    { 'va_eauth_csid' => 'DSLogon', 'va_eauth_authenticationmethod' => 'DSLogon', 'va_eauth_pnidtype' => 'SSN',
      'va_eauth_assurancelevel' => '3', 'va_eauth_firstName' => 'Pauline', 'va_eauth_lastName' => 'Foster',
      'va_eauth_issueinstant' => '2025-08-19T13:57:05Z', 'va_eauth_dodedipnid' => '1243413229',
      'va_eauth_birlsfilenumber' => '123456', 'va_eauth_pid' => '600049703', 'va_eauth_pnid' => '796330625',
      'va_eauth_birthdate' => '1976-06-09T00:00:00+00:00',
      'va_eauth_authorization' => '{"authorizationResponse":{"status":"VETERAN","idType":"SSN","id":"796330625",' \
                                  '"edi":"1243413229","firstName":"Pauline","lastName":"Foster", ' \
                                  '"birthDate":"1976-06-09T00:00:00+00:00",' \
                                  '"gender":"MALE"}}', 'va_eauth_authenticationauthority' => 'eauth',
      'va_eauth_service_transaction_id' => '00000000-0000-0000-0000-000000000000' }
  end
  let(:min_fes_mapped_data) do
    { data: {
      serviceTransactionId: 'claims-api-6913cb91-f077-4368-baf3-1bb642ffc0dd-1755612075',
      claimantParticipantId: '600049703',
      veteranParticipantId: '600049703',
      form526: {
        serviceInformation: {
          servicePeriods: [{
            serviceBranch: 'Air Force', activeDutyBeginDate: '2015-11-14', activeDutyEndDate: '2018-11-30'
          }]
        },
        veteran: { currentMailingAddress: {
          addressLine1: '1234 Couch Street', country: 'USA', zipFirstFive: '12345',
          addressType: 'DOMESTIC', city: 'Portland', state: 'OR'
        } },
        disabilities: [{ name: 'hearing loss', disabilityActionType: 'NEW',
                         approximateBeginDate: { year: 2017, month: 7 } }],
        claimDate: '2025-08-19'
      }
    } }
  end
  let(:fes_claim) do
    claim = create(:auto_established_claim)
    claim.transaction_id = '00000000-0000-0000-000000000000'
    claim.auth_headers = fes_auth_headers
    claim.save
    claim
  end
  let(:async) { true }
  let(:not_async) { false }

  describe '#validate' do
    context 'successful validation' do
      it 'returns validation success' do
        VCR.use_cassette('/claims_api/fes/validate/success') do
          response = service.validate(fes_claim, min_fes_mapped_data, not_async)

          expect(response[:valid]).to be(true)
          expect(response).to have_key(:success)
        end
      end
    end

    context 'validation with errors' do
      it 'returns a 400' do
        VCR.use_cassette('/claims_api/fes/validate/bad_request') do
          expect do
            service.validate(claim, invalid_form_data, not_async)
          end.to raise_error(
            ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException
          )
        end
      end
    end

    context 'invalid data values' do
      it 'returns a 400' do
        invalid_data = min_fes_mapped_data
        invalid_data[:data][:form526][:serviceInformation][:servicePeriods][0][:serviceBranch] = 'AIR\n Force'

        VCR.use_cassette('/claims_api/fes/validate/invalid_request') do
          expect { service.validate(claim, invalid_data, not_async) }
            .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException)
        end
      end
    end
  end

  describe '#submit' do
    context 'successful submission' do
      it 'returns submission success' do
        VCR.use_cassette('/claims_api/fes/submit/success') do
          response = service.submit(fes_claim, min_fes_mapped_data, not_async)

          expect(response[:claimId]).to eq(600883061) # rubocop:disable Style/NumericLiterals
          expect(response[:requestId]).not_to be_nil
        end
      end
    end

    context 'invalid data values' do
      it 'returns a 400' do
        invalid_data = min_fes_mapped_data
        invalid_data[:data][:form526][:serviceInformation][:servicePeriods][0][:serviceBranch] = 'AIR\n Force'

        VCR.use_cassette('/claims_api/fes/submit/invalid_request') do
          expect { service.submit(claim, invalid_form_data, not_async) }
            .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException)
        end
      end
    end

    context 'invalid data format' do
      it 'returns a 400' do
        VCR.use_cassette('/claims_api/fes/submit/bad_request') do
          expect { service.submit(claim, invalid_form_data, not_async) }
            .to raise_error(ClaimsApi::Common::Exceptions::Lighthouse::BackendServiceException)
        end
      end
    end
  end
end
