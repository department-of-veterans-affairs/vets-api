# frozen_string_literal: true

RSpec.shared_examples 'refresh_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:statsd_refresh_error) { SignIn::Constants::Statsd::STATSD_SIS_REFRESH_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] refresh error' }
  let(:expected_error_context) { { errors: expected_error.to_s } }

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed refresh attempt' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
    subject
  end

  it 'updates StatsD with a refresh request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_refresh_error)
  end
end
