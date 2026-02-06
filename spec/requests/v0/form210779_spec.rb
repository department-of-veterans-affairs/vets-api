# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form210779',
               type: :request do
  include StatsD::Instrument::Helpers
  let(:form_data) { { form: VetsJsonSchema::EXAMPLES['21-0779'].to_json }.to_json }
  let(:saved_claim) { create(:va210779) }

  describe 'POST /v0/form210779' do
    context 'when inflection header provided' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form210779',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'X-Key-Inflection' => 'camel',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            }
          )
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'saved_claim.create:1|c|#form_id:21-0779,doctype:222',
          'shared.sidekiq.default.Lighthouse_SubmitBenefitsIntakeClaim.enqueue:1|c',
          'api.form210779.success:1|c|#form:21-0779',
          'api.rack.request:1|c|#controller:v0/form210779,action:create,source_app:21-0779-nursing-home-information,' \
          'status:200'
        )
      end
    end
  end

  describe 'GET /v0/form210779/download_pdf' do
    it 'returns a success' do
      metrics = capture_statsd_calls do
        get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'api.rack.request:1|c|#controller:v0/form210779,action:download_pdf,' \
        'source_app:21-0779-nursing-home-information,status:200'
      )

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq('application/pdf')
    end

    it 'returns 500 when to_pdf returns error' do
      allow_any_instance_of(SavedClaim::Form210779).to receive(:to_pdf).and_raise(StandardError, 'PDF generation error')

      metrics = capture_statsd_calls do
        get("/v0/form210779/download_pdf/#{saved_claim.guid}", headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21-0779-nursing-home-information'
            })
      end
      expect(metrics.collect(&:source)).to include(
        'api.rack.request:1|c|#controller:v0/form210779,action:download_pdf,' \
        'source_app:21-0779-nursing-home-information,status:500'
      )

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['errors']).to be_present
      expect(JSON.parse(response.body)['errors'].first['status']).to eq('500')
    end
  end
end
