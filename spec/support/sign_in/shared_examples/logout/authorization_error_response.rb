# frozen_string_literal: true

RSpec.shared_examples 'logout_authorization_error_response' do
  let(:statsd_failure) { SignIn::Constants::Statsd::STATSD_SIS_LOGOUT_FAILURE }
  let(:expected_error_log) { '[SignInService] [V0::SignInController] logout error' }
  let(:expected_error_context) { { errors: expected_error_message, client_id: client_id_value } }

  it 'triggers statsd increment for failed call' do
    expect { subject }.to trigger_statsd_increment(statsd_failure)
  end

  it 'logs the error message' do
    expect(Rails.logger).to receive(:info).with(expected_error_log, expected_error_context)
    subject
  end

  context 'when client configuration has not configured a logout redirect uri' do
    let(:logout_redirect_uri) { nil }
    let(:expected_error_status) { :ok }

    it 'returns expected status' do
      expect(subject).to have_http_status(expected_error_status)
    end
  end

  context 'when client configuration has configured a logout redirect uri' do
    let(:logout_redirect_uri) { 'some-logout-redirect-uri' }
    let(:expected_error_status) { :redirect }

    it 'returns expected status' do
      expect(subject).to have_http_status(expected_error_status)
    end

    it 'redirects to logout redirect url' do
      expect(subject).to redirect_to(logout_redirect_uri)
    end
  end
end
