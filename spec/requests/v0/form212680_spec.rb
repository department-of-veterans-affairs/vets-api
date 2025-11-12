# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form212680', type: :request do
  include StatsD::Instrument::Helpers
  let(:form_data) { VetsJsonSchema::EXAMPLES['21-2680'] }
  let(:valid_request) { { form: form_data }.to_json }
  let(:tags) do
    ["#controller:v0/form212680,action:download_pdf,source_app:21-2680-house-bound-status,status:#{status}"]
  end

  context 'while inflection header provided' do
    let(:status) { '200' }

    it 'returns a success' do
      metrics = capture_statsd_calls do
        post(
          '/v0/form212680/download_pdf',
          params: valid_request,
          headers: {
            'Content-Type' => 'application/json',
            'X-Key-Inflection' => 'camel',
            'HTTP_SOURCE_APP_NAME' => '21-2680-house-bound-status'
          }
        )
      end
      expect(metrics.collect(&:source)).to include(
        'saved_claim.create:1|c|#form_id:21-2680,doctype:540',
        'api.rack.request:1|c|#controller:v0/form212680,action:download_pdf,' \
        'source_app:21-2680-house-bound-status,status:200'
      )

      expect(response).to have_http_status(:ok)
    end
  end

  context 'when pdf generation raises' do
    let(:status) { '500' }

    it 'returns a properly handled error' do
      allow_any_instance_of(SavedClaim).to receive(:to_pdf).and_raise(StandardError, 'PDF generation error')

      metrics = capture_statsd_calls do
        post(
          '/v0/form212680/download_pdf',
          params: valid_request,
          headers: {
            'Content-Type' => 'application/json',
            'X-Key-Inflection' => 'camel',
            'HTTP_SOURCE_APP_NAME' => '21-2680-house-bound-status'
          }
        )
      end

      expect(metrics.collect(&:source)).to include(
        'saved_claim.create:1|c|#form_id:21-2680,doctype:540',
        'api.rack.request:1|c|#controller:v0/form212680,action:download_pdf,' \
        'source_app:21-2680-house-bound-status,status:500'
      )
      expect(response).to have_http_status(:internal_server_error)
    end
  end
end
