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

  describe '#perform' do
    let(:file_number) { '123456' }
    let(:middle_initial) { '' }

    describe 'handles a successful claim correctly' do
      described_class.new

      it 'submits successfully' do
        expect do
          subject.perform_async(claim.id, middle_initial, file_number)
        end.to change(subject.jobs, :size).by(1)
      end

      # it 'calls the next job when the claim.status is not errored' do
      #   allow(service).to receive(:generate_526_pdf).and_return('sample pdf string')

      #   service.instance_variable_set(:@pdf_string, 'sample pdf string')

      #   service.perform(claim.id, middle_initial, file_number)

      #   claim.reload
      #   expect(subject).to receive(:start_evss_job).with(claim.id, file_number)
      # end
    end

    describe 'handles an errored claim correctly' do
      service = described_class.new

      it 'sets claim state to errored when pdf_string is empty' do
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find).with(claim.id).and_return(claim)
        allow(service).to receive(:generate_526_pdf).and_return('')

        service.perform(claim.id, middle_initial, file_number)

        claim.reload
        expect(claim.status).to eq('errored')
      end

      it 'does not call the next job when the claim.status is errored' do
        allow(ClaimsApi::AutoEstablishedClaim).to receive(:find).with(claim.id).and_return(claim)
        allow(service).to receive(:generate_526_pdf).and_return('')

        service.perform(claim.id, middle_initial, file_number)

        claim.reload
        expect(service).not_to receive(:start_evss_job)
      end
    end
  end

  # if @claim.status != 'errored' it does start next job
end
