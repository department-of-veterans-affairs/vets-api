# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

RSpec.describe RapidReadyForDecision::Form526AsthmaJob, type: :worker do
  around do |example|
    VCR.use_cassette('evss/claims/claims_without_open_compensation_claims', &example)
  end

  before { Flipper.disable(:rrd_call_vro_service) }

  let(:submission) { create(:form526_submission, :asthma_claim_for_increase) }

  describe '#perform' do
    subject { RapidReadyForDecision::Form526AsthmaJob.perform_async(submission.id) }

    around do |example|
      VCR.use_cassette('rrd/asthma', &example)
    end

    context 'success' do
      it 'finishes successfully' do
        Sidekiq::Testing.inline! do
          expect { subject }.not_to raise_error
          submission.reload
          expect(submission.form.dig('rrd_metadata', 'med_stats', 'medications_count')).to eq(11)
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
