# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require './modules/claims_api/app/services/claims_api/disability_compensation/form526_establishment_service'

describe ClaimsApi::DisabilityCompensation::Form526EstablishmentService do
  before do
    stub_claims_api_auth_token
  end

  let(:form526_establishment_service) { ClaimsApi::DisabilityCompensation::Form526EstablishmentService.new }
  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
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
  let(:claim_date) { (Time.zone.today - 1.day).to_s }
  let(:anticipated_separation_date) { 2.days.from_now.strftime('%m-%d-%Y') }
  let(:form_data) do
    temp = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', 'v2', 'veterans', 'disability_compensation',
                           'form_526_json_api.json').read
    temp = JSON.parse(temp)
    attributes = temp['data']['attributes']
    attributes['claimDate'] = claim_date
    attributes['serviceInformation']['federalActivation']['anticipatedSeparationDate'] = anticipated_separation_date

    temp['data']['attributes']
  end
  let(:min_fes_form_data) do
    {
      claimProcessType: 'STANDARD_CLAIM_PROCESS',
      veteranIdentification: {
        mailingAddress: {
          addressLine1: '1234 Couch Street',
          city: 'Portland',
          state: 'OR',
          country: 'USA',
          zipFirstFive: '12345'
        },
        currentVaEmployee: false
      },
      disabilities: [
        {
          name: 'hearing loss',
          serviceRelevance: 'Heavy equipment operator in service',
          approximateDate: '2017-07',
          disabilityActionType: 'NEW'
        }
      ],
      serviceInformation: {
        servicePeriods: [
          {
            serviceBranch: 'Air Force',
            serviceComponent: 'Active',
            activeDutyBeginDate: '2015-11-14',
            activeDutyEndDate: '2018-11-30'
          }
        ]
      },
      claimantCertification: true
    }
  end
  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end
  let(:fes_claim) do
    claim = create(:auto_established_claim, form_data: min_fes_form_data)
    claim.transaction_id = '00000000-0000-0000-000000000000'
    claim.auth_headers = fes_auth_headers
    claim.save
    claim
  end
  let(:claim_with_transaction_id) do
    claim = create(:auto_established_claim, form_data:)
    claim.transaction_id = '00000000-0000-0000-000000000000'
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#upload' do
    context 'using the EVSS Service' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_enable_FES).and_return(false)
      end

      it 'has a upload method that returns a claim id' do
        VCR.use_cassette('/claims_api/evss/submit') do
          expect(form526_establishment_service.send(:upload, claim.id)).to be(true)
        end
      end

      it 'adds the transaction_id to the headers' do
        VCR.use_cassette('/claims_api/evss/submit') do
          form526_establishment_service.send(:upload, claim_with_transaction_id.id)
          claim_with_transaction_id.reload
          expect(claim_with_transaction_id.auth_headers['va_eauth_service_transaction_id'])
            .to eq(claim_with_transaction_id.transaction_id)
        end
      end

      it 'logs the transaction_id' do
        VCR.use_cassette('/claims_api/evss/submit') do
          expect(Rails.logger).to receive(:info).with(/#{claim_with_transaction_id.transaction_id}/).at_least(:once)
          form526_establishment_service.send(:upload, claim_with_transaction_id.id)
        end
      end

      context 'the error is saved on the claim in the evss_response attribute' do
        errors = {
          messages: [
            {
              'key' => 'header.va_eauth_birlsfilenumber.Invalid',
              'severity' => 'ERROR',
              'text' => 'Size must be between 8 and 9'
            }
          ]
        }
        let(:file_number) { '635781568' }

        it 'sets the evss_response to the original body error message' do
          evss_mapper_stub = instance_double(ClaimsApi::V2::DisabilityCompensationEvssMapper)
          allow(ClaimsApi::V2::DisabilityCompensationEvssMapper).to receive(:new) { evss_mapper_stub }
          allow(evss_mapper_stub).to receive(:map_claim).and_raise(Common::Exceptions::BackendServiceException.new(
                                                                     errors
                                                                   ))
          begin
            allow(subject).to receive(:upload).with(claim.id).and_raise(
              Common::Exceptions::UnprocessableEntity
            )
          rescue => e
            claim.reload
            expect(claim.evss_id).to be_nil
            expect(claim.evss_response).to eq([{ 'title' => 'Operation failed', 'detail' => 'Operation failed',
                                                 'code' => 'VA900', 'status' => '400' }])
            expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
            expect(e.message).to include 'Unprocessable Entity'
          end
        end
      end
    end

    context 'using the FES Service' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v2_enable_FES).and_return(true)
      end

      it 'has a upload method that returns a claim id' do
        VCR.use_cassette('/claims_api/fes/submit') do
          expect(form526_establishment_service.send(:upload, fes_claim.id)).to be(true)
        end
      end

      it 'adds the transaction_id to the headers' do
        VCR.use_cassette('/claims_api/fes/submit') do
          form526_establishment_service.send(:upload, claim_with_transaction_id.id)
          claim_with_transaction_id.reload
          expect(claim_with_transaction_id.auth_headers['va_eauth_service_transaction_id'])
            .to eq(claim_with_transaction_id.transaction_id)
        end
      end

      it 'logs the transaction_id' do
        VCR.use_cassette('/claims_api/fes/submit') do
          expect(Rails.logger).to receive(:info).with(/#{claim_with_transaction_id.transaction_id}/).at_least(:once)
          form526_establishment_service.send(:upload, claim_with_transaction_id.id)
        end
      end

      context 'the error is saved on the claim in the evss_response attribute' do
        errors = {
          messages: [
            {
              'key' => 'header.va_eauth_birlsfilenumber.Invalid',
              'severity' => 'ERROR',
              'text' => 'Size must be between 8 and 9'
            }
          ]
        }
        let(:file_number) { '635781568' }

        it 'sets the evss_response to the original body error message' do
          evss_mapper_stub = instance_double(ClaimsApi::V2::DisabilityCompensationEvssMapper)
          allow(ClaimsApi::V2::DisabilityCompensationEvssMapper).to receive(:new) { evss_mapper_stub }
          allow(evss_mapper_stub).to receive(:map_claim).and_raise(Common::Exceptions::BackendServiceException.new(
                                                                     errors
                                                                   ))
          begin
            allow(subject).to receive(:upload).with(claim.id).and_raise(
              Common::Exceptions::UnprocessableEntity
            )
          rescue => e
            claim.reload
            expect(claim.evss_id).to be_nil
            expect(claim.evss_response).to eq([{ 'title' => 'Operation failed', 'detail' => 'Operation failed',
                                                 'code' => 'VA900', 'status' => '400' }])
            expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
            expect(e.message).to include 'Unprocessable Entity'
          end
        end
      end
    end
  end
end
