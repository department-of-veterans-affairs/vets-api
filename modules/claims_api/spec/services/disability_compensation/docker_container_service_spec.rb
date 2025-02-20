# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require './modules/claims_api/app/services/claims_api/disability_compensation/docker_container_service'

describe ClaimsApi::DisabilityCompensation::DockerContainerService do
  before do
    stub_claims_api_auth_token
  end

  let(:docker_container_service) { ClaimsApi::DisabilityCompensation::DockerContainerService.new }
  let(:user) { create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
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
  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
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
    it 'has a upload method that returns a claim id' do
      VCR.use_cassette('/claims_api/evss/submit') do
        expect(docker_container_service.send(:upload, claim.id)).to be(true)
      end
    end

    it 'adds the transaction_id to the headers' do
      VCR.use_cassette('/claims_api/evss/submit') do
        docker_container_service.send(:upload, claim_with_transaction_id.id)
        claim_with_transaction_id.reload
        expect(claim_with_transaction_id.auth_headers['va_eauth_service_transaction_id'])
          .to eq(claim_with_transaction_id.transaction_id)
      end
    end

    it 'logs the transaction_id' do
      VCR.use_cassette('/claims_api/evss/submit') do
        expect(Rails.logger).to receive(:info).with(/#{claim_with_transaction_id.transaction_id}/).at_least(:once)
        docker_container_service.send(:upload, claim_with_transaction_id.id)
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
