# frozen_string_literal: true

RSpec.shared_examples 'logout_error_response' do
  let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] logout error' }
  let(:expected_error_context) { { errors: expected_error_message, client_id: client_id_value } }
  let(:expected_error_status) { :bad_request }
  let(:expected_error_json) { { 'errors' => expected_error_message } }

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'triggers statsd increment for failed call' do
    expect { subject }.to trigger_statsd_increment(statsd_failure)
  end

  it 'logs the error message' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
    subject
  end
end
