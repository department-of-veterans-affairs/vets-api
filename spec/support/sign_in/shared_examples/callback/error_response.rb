# frozen_string_literal: true

RSpec.shared_examples 'callback_error_response' do
  let(:expected_error_json) { { 'errors' => expected_error } }
  let(:expected_error_status) { :bad_request }
  let(:statsd_callback_failure) { SignIn::Constants::Statsd::STATSD_SIS_CALLBACK_FAILURE }
  let(:expected_statsd_tags) do
    ["type:#{type || ''}", "client_id:#{client_id || ''}", "acr:#{acr || ''}", "operation:#{operation || ''}"]
  end

  context 'and client_id maps to a web based configuration' do
    let(:authentication) { SignIn::Constants::Auth::COOKIE }
    let(:expected_error_status) { :ok }
    let(:auth_param) { 'fail' }
    let(:expected_error_log) { '[SignInService] [V0::SignInController] callback error' }
    let(:expected_error_message) { { errors: expected_error, client_id:, type:, acr:, operation: } }
    let(:request_id) { SecureRandom.uuid }
    let(:meta_refresh_tag) { '<meta http-equiv="refresh" content="0;' }

    before do
      allow_any_instance_of(ActionController::TestRequest).to receive(:request_id).and_return(request_id)
    end

    it 'renders the oauth_get_form template with meta refresh tag' do
      expect(subject.body).to include(meta_refresh_tag)
    end

    it 'directs to the given redirect url set in the client configuration' do
      expect(subject.body).to include(client_config.redirect_uri)
    end

    it 'includes expected auth param' do
      expect(subject.body).to include(auth_param)
    end

    it 'includes expected code param' do
      expect(subject.body).to include(error_code)
    end

    it 'includes expected request_id param' do
      expect(subject.body).to include(request_id)
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

  context 'and client_id maps to an api based configuration' do
    let(:authentication) { SignIn::Constants::Auth::API }

    it_behaves_like 'callback_api_error_response'
  end
end
