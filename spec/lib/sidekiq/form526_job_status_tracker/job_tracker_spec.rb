# frozen_string_literal: true

require 'rails_helper'

describe Sidekiq::Form526JobStatusTracker::JobTracker do
  let(:dummy_class) { Class.new { include Sidekiq::Form526JobStatusTracker::JobTracker } }

  context 'with an exhausted callback message' do
    let(:msg) do
      {
        'class' => 'EVSS::DisabilityCompensationForm::SubmitForm526AllClaim',
        'jid' => SecureRandom.uuid,
        'args' => [123],
        'error_message' => 'Did not receive a timely response from an upstream server',
        'error_class' => 'Common::Exceptions::GatewayTimeout'
      }
    end
    let!(:form526_submission) { create :form526_submission }
    let!(:from526_job_status) do
      create :form526_job_status, job_id: msg['jid'], form526_submission: form526_submission
    end

    it 'tracks an exhausted job' do
      expect_any_instance_of(Sidekiq::Form526JobStatusTracker::Metrics).to receive(:increment_exhausted)
      dummy_class.job_exhausted(msg, 'stats_key')
      job_status = Form526JobStatus.last

      expect(job_status.status).to eq 'exhausted'
      expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
      expect(job_status.error_message).to eq msg['error_message']
      expect(job_status.form526_submission_id).to eq 123

      expect(job_status.bgjob_errors).to be_a Hash
      key = job_status.bgjob_errors.keys.first
      expect(job_status.bgjob_errors[key].keys).to match_array %w[timestamp caller_method error_class error_message]
      expect(job_status.bgjob_errors[key]['caller_method']).to match 'job_exhausted'
    end
  end
end
