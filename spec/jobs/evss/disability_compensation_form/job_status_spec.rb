# frozen_string_literal: true

require 'rails_helper'

describe EVSS::DisabilityCompensationForm::JobStatus do
  let(:dummy_class) { Class.new { include EVSS::DisabilityCompensationForm::JobStatus } }

  context 'with an exhausted callback message' do
    let(:msg) do
      {
        'jid' => SecureRandom.uuid,
        'args' => [123],
        'error_message' => 'Did not receive a timely response from an upstream server'
      }
    end

    it 'tracks an exhausted job' do
      dummy_class.job_exhausted(msg)
      expect(Form526JobStatus.last.status).to eq 'exhausted'
    end
  end
end
