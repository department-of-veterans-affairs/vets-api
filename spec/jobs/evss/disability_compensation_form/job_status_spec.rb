# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::JobStatus do
  let(:dummy_class) { Class.new { include EVSS::DisabilityCompensationForm::JobStatus } }

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

    it 'tracks an exhausted job' do
      dummy_class.job_exhausted(msg)
      job_status = Form526JobStatus.last
      expect(job_status.status).to eq 'exhausted'
      expect(job_status.job_class).to eq 'SubmitForm526AllClaim'
      expect(job_status.error_message).to eq msg['error_message']
      expect(job_status.form526_submission_id).to eq 123
    end
  end
end
