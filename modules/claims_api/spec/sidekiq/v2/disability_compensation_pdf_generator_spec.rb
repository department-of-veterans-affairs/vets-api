# frozen_string_literal: true

require 'rails_helper'
require_relative '../../rails_helper'
require 'claims_api/v2/disability_compensation_pdf_generator'

RSpec.describe ClaimsApi::V2::DisabilityCompensationPdfGenerator, type: :job do
  subject { described_class }

  before do
    Sidekiq::Job.clear_all
    stub_claims_api_auth_token
  end

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

  let(:errored_claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.status = ClaimsApi::AutoEstablishedClaim::ERRORED
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe '#perform' do
    let(:middle_initial) { '' }

    service = described_class.new

    context 'handles a successful claim correctly' do
      it 'submits successfully' do
        expect do
          subject.perform_async(claim.id, middle_initial)
        end.to change(subject.jobs, :size).by(1)
      end

      it 'sets the claim status to pending when starting/rerunning' do
        VCR.use_cassette('claims_api/disability_comp') do
          expect(errored_claim.status).to eq('errored')

          service.perform(errored_claim.id, middle_initial)
          errored_claim.reload
          expect(errored_claim.status).to eq('pending')
        end
      end
    end

    context 'handles an errored claim correctly' do
      it 'sets claim state to errored when pdf_string is empty' do
        VCR.use_cassette('claims_api/disability_comp') do
          allow(service).to receive(:generate_526_pdf).and_return('')

          service.perform(claim.id, middle_initial)

          claim.reload
          expect(claim.status).to eq('errored')
        end
      end

      it 'does not call the next job when the claim.status is errored' do
        VCR.use_cassette('claims_api/disability_comp') do
          allow(service).to receive(:generate_526_pdf).and_return('')

          service.perform(claim.id, middle_initial)

          claim.reload
          expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
          expect(service).not_to receive(:start_docker_container_job)
        end
      end
    end
  end

  describe 'when an errored job has exhausted its retries' do
    it 'logs to the ClaimsApi Logger' do
      error_msg = 'An error occurred from the PDF Generator Job'
      msg = { 'args' => [claim.id, ''],
              'class' => subject,
              'error_message' => error_msg }

      described_class.within_sidekiq_retries_exhausted_block(msg) do
        expect(ClaimsApi::Logger).to receive(:log).with(
          'claims_api_retries_exhausted',
          record_id: claim.id,
          detail: "Job retries exhausted for #{subject}",
          error: error_msg
        )
      end
    end
  end

  describe 'when an errored job has a time limitation' do
    it 'logs to the ClaimsApi Logger' do
      described_class.within_sidekiq_retries_exhausted_block do
        expect(subject).to be_expired_in 48.hours
      end
    end
  end
end
