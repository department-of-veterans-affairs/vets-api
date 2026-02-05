# frozen_string_literal: true

require 'rails_helper'

require 'lighthouse/benefits_intake/monitor'

RSpec.describe BenefitsIntake::Monitor do
  let(:monitor) { described_class.new }

  it 'has required properties' do
    expect(monitor.tags).to eq([])

    expect(monitor).to respond_to(:track_submission_begun)
    expect(monitor).to respond_to(:track_submission_attempted)
    expect(monitor).to respond_to(:track_submission_success)
    expect(monitor).to respond_to(:track_submission_retry)
    expect(monitor).to respond_to(:track_submission_exhaustion)
    expect(monitor).to respond_to(:track_send_email_failure)
    expect(monitor).to respond_to(:track_file_cleanup_error)

    expect(monitor).to receive(:submit_event)
    monitor.track_submission_begun('claim', nil, nil)
  end
end
