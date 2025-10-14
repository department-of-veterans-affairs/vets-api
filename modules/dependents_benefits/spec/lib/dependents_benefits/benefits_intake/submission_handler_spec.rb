# frozen_string_literal: true

require 'rails_helper'
require 'dependents_benefits/benefits_intake/submission_handler'
require 'dependents_benefits/monitor'

Rspec.describe DependentsBenefits::BenefitsIntake::SubmissionHandler do
  let(:handler) { DependentsBenefits::BenefitsIntake::SubmissionHandler }
  let(:claim) { build(:dependents_claim) }
  let(:monitor) { double(DependentsBenefits::Monitor) }
  let(:instance) { handler.new('fake-claim-id') }

  before do
    allow(DependentsBenefits::SavedClaim).to receive(:find).and_return claim
    allow(DependentsBenefits::Monitor).to receive(:new).and_return monitor
  end

  describe '.pending_attempts' do
    let(:submission_attempt) { double('Lighthouse::SubmissionAttempt') }
    let(:submission) { double('Lighthouse::Submission', form_id: '686C-674-V2') }

    before do
      allow(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
                                                             .and_return(Lighthouse::SubmissionAttempt)
      allow(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                   'lighthouse_submissions.form_id' => '686C-674-V2')
                                                             .and_return([submission_attempt])
    end

    it 'returns pending submission attempts with the correct form_id' do
      result = handler.pending_attempts
      expect(result).to eq([submission_attempt])
    end

    it 'queries with the correct status and form_id' do
      expect(Lighthouse::SubmissionAttempt).to receive(:joins).with(:submission)
      expect(Lighthouse::SubmissionAttempt).to receive(:where).with(status: 'pending',
                                                                    'lighthouse_submissions.form_id' => '686C-674-V2')
      handler.pending_attempts
    end
  end

  describe '#on_stale' do
    it 'does nothing' do
      # pass thru for coverage
      expect(instance.handle(:stale)).to be true
    end
  end
end
