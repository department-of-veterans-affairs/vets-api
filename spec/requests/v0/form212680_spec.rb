# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form212680', type: :request do
  include StatsD::Instrument::Helpers
  let(:form_data) { { form: VetsJsonSchema::EXAMPLES['21-2680'].to_json }.to_json }
  let(:saved_claim) { create(:form212680) }
  let(:user) { create(:user, :loa3) }

  before do
    sign_in_as(user)
  end

  describe 'POST /v0/form212680' do
    context 'when inflection header provided' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form212680',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'X-Key-Inflection' => 'camel',
              'HTTP_SOURCE_APP_NAME' => '21-2680-house-bound-status'
            }
          )
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'saved_claim.create:1|c|#form_id:21-2680,doctype:540',
          'api.form212680.success:1|c|#form:21-2680',
          'api.rack.request:1|c|#controller:v0/form212680,action:create,' \
          'source_app:21-2680-house-bound-status,status:200'
        )
      end
    end
  end

  describe 'GET /v0/form212680/download_pdf' do
    it 'returns a success' do
      metrics = capture_statsd_calls do
        get("/v0/form212680/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-2680-house-bound-status'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'saved_claim.create:1|c|#form_id:21-2680,doctype:540',
        'api.rack.request:1|c|#controller:v0/form212680,action:download_pdf,' \
        'source_app:21-2680-house-bound-status,status:200'
      )

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end

    it 'returns 500 when to_pdf returns error' do
      allow_any_instance_of(SavedClaim::Form212680).to receive(:to_pdf).and_raise(StandardError, 'PDF generation error')

      metrics = capture_statsd_calls do
        get("/v0/form212680/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-2680-house-bound-status'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'api.rack.request:1|c|#controller:v0/form212680,action:download_pdf,' \
        'source_app:21-2680-house-bound-status,status:500'
      )

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['errors']).to be_present
      expect(JSON.parse(response.body)['errors'].first['status']).to eq('500')
    end
  end
end
