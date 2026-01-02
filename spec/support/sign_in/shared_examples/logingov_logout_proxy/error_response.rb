# frozen_string_literal: true

RSpec.shared_examples 'logingov_logout_proxy_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] logingov_logout_proxy error' }
  let(:expected_error_message) do
    { errors: expected_error }
  end

  it 'renders expected error' do
    expect(JSON.parse(subject.body)).to eq(expected_error_json)
  end

  it 'returns expected status' do
    expect(subject).to have_http_status(expected_error_status)
  end

  it 'logs the failed logingov_logout_proxy attempt' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_message)
    subject
  end
end
