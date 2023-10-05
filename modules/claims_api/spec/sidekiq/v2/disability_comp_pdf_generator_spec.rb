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
    {'Authorization' => 'Bearer faketokenhere'}
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

    temp.to_json
  end

  let(:claim) do
    claim = create(:auto_established_claim, form_data:)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  describe 'successful submission' do
    it 'submits successfully' do
      expect do
        subject.new.perform(claim)
      end.to change(subject.jobs, :size).by(1)
    end

    it 'handles the claim' do
      subject.new.perform(claim)
    end
  end

  describe '#log_job_progress' do
    let(:claim) { double('Claim', id: 123) }
    let(:start_detail) { '526EZ PDF generator started.' }
    let(:finish_detail) { '526EZ PDF generator finished.' }

    subject { described_class.new }

    it 'logs the progress when starting' do
      logger = instance_double(ClaimsApi::Logger)
      expect(ClaimsApi::Logger).to receive(:log)
        .with('dis_comp_pdf_generator', 
              claim_id: claim.id, 
              detail: "#{start_detail}")

      subject.send(:log_job_progress, claim, start_detail)
    end

    it 'logs the progress when finished' do
      logger = instance_double(ClaimsApi::Logger)
      expect(ClaimsApi::Logger).to receive(:log)
        .with('dis_comp_pdf_generator', 
              claim_id: claim.id, 
              detail: "#{finish_detail}")

      subject.send(:log_job_progress, claim, finish_detail)
    end
  end
end