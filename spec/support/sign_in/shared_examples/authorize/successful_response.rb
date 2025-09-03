# frozen_string_literal: true

RSpec.shared_examples 'authorize_successful_response' do
  it 'returns ok status' do
    expect(subject).to have_http_status(:ok)
  end

  it 'renders expected state' do
    expect(subject.body).to match(state)
  end

  it 'renders expected redirect_uri in template' do
    expect(subject.body).to match(expected_redirect_uri_param)
  end

  it 'renders expected op value in template' do
    expect(subject.body).to match(expected_op_value)
  end

  it 'logs the authentication attempt' do
    expect(Rails.logger).to receive(:info).with(expected_log, expected_logger_context)
    subject
  end

  it 'updates StatsD with a auth request success' do
    expect { subject }.to trigger_statsd_increment(statsd_auth_success, tags: statsd_tags)
  end
end
