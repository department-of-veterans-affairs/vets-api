# frozen_string_literal: true

RSpec.shared_examples 'callback_api_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
  let(:expected_error_message) do
    { errors: expected_error, client_id:, type:, acr:, operation: }
  end
  let(:expected_statsd_tags) do
    ["type:#{type || ''}", "client_id:#{client_id || ''}", "acr:#{acr || ''}", "operation:#{operation || ''}"]
  end

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed callback' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
    subject
  end

  it 'updates StatsD with a callback request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_callback_failure, tags: expected_statsd_tags)
  end
end
