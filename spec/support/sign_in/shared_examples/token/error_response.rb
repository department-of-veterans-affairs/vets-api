# frozen_string_literal: true

RSpec.shared_examples 'token_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:statsd_token_failure) { SignIn::Constants::Statsd::STATSD_SIS_TOKEN_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] token error' }
  let(:expected_error_context) { { errors: expected_error.to_s, grant_type: grant_type_value } }

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed token request' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
    subject
  end

  it 'updates StatsD with a token request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_token_failure)
  end
end
