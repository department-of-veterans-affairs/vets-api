# frozen_string_literal: true

RSpec.shared_examples 'authorize_api_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_auth_failure) { SignIn::Constants::Statsd::STATSD_SIS_AUTHORIZE_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] authorize error' }
  let(:expected_error_message) do
    { errors: expected_error, client_id: client_id_value, type: type_value, acr: acr_value,
      operation: operation_value || SignIn::Constants::Auth::AUTHORIZE }
  end

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed authorize attempt' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
    subject
  end

  it 'updates StatsD with a auth request failure' do
    expect { subject }.to trigger_statsd_increment(statsd_auth_failure)
  end
end
