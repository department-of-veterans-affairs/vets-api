# frozen_string_literal: true

require 'rails_helper'
require 'faraday'
require 'json'

RSpec.describe AccreditationService do
  let(:parsed_body) { { field: 'value' } }
  let(:user_uuid) { 'test-user-uuid' }
  let(:monitor) { instance_double(AccreditedRepresentativePortal::MonitoringService) }
  let(:span) { instance_double(Datadog::Tracing::SpanOperation) }

  before do
    allow(AccreditedRepresentativePortal::MonitoringService).to receive(:new).and_return(monitor)
    allow(monitor).to receive(:track_event)
    allow(monitor).to receive(:track_error)

    # Fix: Ensure `with_tracing` is properly mocked
    allow(monitor).to receive(:with_tracing).and_yield(span)
    allow(span).to receive(:set_tag)
    allow(span).to receive(:set_error)
  end

  describe '#submit_form21a' do
    context 'when the request is successful' do
      it 'returns a successful response and traces the request' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_return(status: 200, body: parsed_body.to_json, headers: { 'Content-Type' => 'application/json' })

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(200)
        expect(response.body).to eq(parsed_body.stringify_keys)

        expect(monitor).to have_received(:with_tracing).with('api.arp.form21a.submit').once
        expect(monitor).to have_received(:track_event).with(
          :info, 'Submitting Form 21a', 'api.arp.form21a.submit', ["user_uuid:#{user_uuid}"]
        )
        expect(monitor).to have_received(:track_event).with(
          :info, 'Form 21a Submission Success', 'api.arp.form21a.success', ["user_uuid:#{user_uuid}"]
        )
      end
    end

    context 'when the connection fails' do
      it 'logs the error, returns a service unavailable status, and traces the failure' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_raise(Faraday::ConnectionFailed.new('Accreditation Service connection failed'))

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(:service_unavailable) # 503
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service unavailable')

        expect(monitor).to have_received(:with_tracing).with('api.arp.form21a.submit').once
        expect(monitor).to have_received(:track_error).with(
          'Accreditation Service Connection Failed',
          'api.arp.form21a.connection_failed',
          'Faraday::ConnectionFailed',
          ["user_uuid:#{user_uuid}", 'error:Accreditation Service connection failed']
        )
      end
    end

    context 'when the request times out' do
      it 'logs the error, returns a request timeout status, and traces the failure' do
        stub_request(:post, Settings.ogc.form21a_service_url.url)
          .to_raise(Faraday::TimeoutError.new('Request timed out'))

        response = described_class.submit_form21a(parsed_body, user_uuid)

        expect(response.status).to eq(:request_timeout) # 408
        expect(JSON.parse(response.body)['errors']).to eq('Accreditation Service request timed out')

        expect(monitor).to have_received(:with_tracing).with('api.arp.form21a.submit').once
        expect(monitor).to have_received(:track_error).with(
          'Accreditation Service Timeout',
          'api.arp.form21a.timeout',
          'Faraday::TimeoutError',
          ["user_uuid:#{user_uuid}", 'error:Request timed out']
        )
      end
    end
  end
end
