# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526AsthmaJob, type: :worker do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:disabilities_compensation_user, icn: '2000163') }
  let(:submission) { create(:form526_submission, :asthma_claim_for_increase, user: user) }

  describe '#perform', :vcr do
    subject { RapidReadyForDecision::Form526AsthmaJob.perform_async(submission.id) }

    around do |example|
      VCR.use_cassette('evss/claims/claims_without_open_compensation_claims', &example)
    end

    context 'success' do
      it 'finishes successfully' do
        Sidekiq::Testing.inline! do
          expect { subject }.not_to raise_error
          submission.reload
          expect(submission.form.dig('rrd_metadata', 'med_stats', 'medications_count')).to eq(19)
        end
      end

      it 'creates a job status record' do
        Sidekiq::Testing.inline! do
          expect { subject }.to change(Form526JobStatus, :count).by(1)
        end
      end

      it 'marks the new Form526JobStatus record as successful' do
        Sidekiq::Testing.inline! do
          subject
          expect(Form526JobStatus.last.status).to eq 'success'
        end
      end
    end
  end
end
