# frozen_string_literal: true

RSpec.shared_examples 'revoke_all_sessions_error_response' do
  let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_REVOKE_ALL_SESSIONS_FAILURE }
  let(:expected_error_json) { { 'errors' => expected_error_message } }
  let(:expected_error_status) { :unauthorized }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] revoke all sessions error' }
  let(:expected_error_context) { { errors: expected_error_message } }

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed revoke all sessions call' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
    subject
  end

  it 'triggers statsd increment for failed call' do
    expect { subject }.to trigger_statsd_increment(statsd_failure)
  end
end
