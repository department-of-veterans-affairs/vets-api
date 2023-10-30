# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v2/disability_compensation_pdf_generator'

RSpec.describe ClaimsApi::V2::DisabilityCompensationDockerContainerUpload, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

  let(:user) { FactoryBot.create(:user, :loa3) }

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

  let(:claim_with_evss_response) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.evss_response = 'Just a test evss error response'
    claim.save
    claim
  end

  let(:errored_claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#perform' do
    service = described_class.new

    context 'successful submission' do
      it 'submits successfully' do
        expect do
          subject.perform_async(claim.id)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'sets the claim status to pending when starting/rerunning' do
        VCR.use_cassette('claims_api/evss/submit') do
          expect(errored_claim.status).to eq('errored')

          service.perform(errored_claim.id)

          errored_claim.reload
          expect(errored_claim.status).to eq('pending')
        end
      end
    end

    it 'removes the evss_response on successful docker Container submission' do
      VCR.use_cassette('claims_api/evss/submit') do
        expect(claim_with_evss_response.status).to eq('errored')
        expect(claim_with_evss_response.evss_response).to eq('Just a test evss error response')

        service.perform(claim_with_evss_response.id)

        claim_with_evss_response.reload
        expect(claim_with_evss_response.status).to eq('pending')
        expect(claim_with_evss_response.evss_response).to eq(nil)
      end
    end

    context 'handles an errored claim correctly' do
      it 'does not call the next job when the claim.status is errored' do
        allow(errored_claim).to receive(:status).and_return('errored')

        subject.perform_async(errored_claim.id)

        errored_claim.reload
        expect(service).not_to receive(:start_bd_uploader_job)
      end
    end
  end
end
