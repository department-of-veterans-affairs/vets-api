# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::form21p530a',
               type: :request do
  include StatsD::Instrument::Helpers
  let(:form_data) { Rails.root.join('spec', 'fixtures', 'form21p530a', 'valid_form.json').read }

  let(:saved_claim) { create(:va210779) }

  describe 'POST /v0/form21p530a' do
    context 'when inflection header provided' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form21p530a',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'X-Key-Inflection' => 'camel',
              'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
            }
          )
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'saved_claim.create:1|c|#form_id:21P-530A,doctype:540',
          'shared.sidekiq.default.Lighthouse_SubmitBenefitsIntakeClaim.enqueue:1|c',
          'api.form21p530a.success:1|c',
          'api.rack.request:1|c|#controller:v0/form21p530a,action:create,source_app:21p-530a-interment-allowance,' \
          'status:200'
        )
      end
    end

    context 'when inflection header omitted' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form21p530a',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
            }
          )
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'saved_claim.create:1|c|#form_id:21P-530A,doctype:540',
          'shared.sidekiq.default.Lighthouse_SubmitBenefitsIntakeClaim.enqueue:1|c',
          'api.form21p530a.success:1|c',
          'api.rack.request:1|c|#controller:v0/form21p530a,action:create,source_app:21p-530a-interment-allowance,' \
          'status:200'
        )
      end
    end

    context 'when form data is invalid' do
      let(:form_data) { Rails.root.join('spec', 'fixtures', 'form21p530a', 'invalid_form.json').read }

      it 'returns a unprocessable_entity' do
        metrics = capture_statsd_calls do
          post(
            '/v0/form21p530a',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'X-Key-Inflection' => 'camel',
              'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
            }
          )
        end
        expect(response).to have_http_status(:unprocessable_entity)
        expect(metrics.collect(&:source)).to include(
          'api.form21p530a.failure:1|c',
          'api.rack.request:1|c|#controller:v0/form21p530a,action:create,source_app:21p-530a-interment-allowance,' \
          'status:422'
        )
      end
    end

    context 'when an unexpected error occurs' do
      it 'returns an error' do
        allow_any_instance_of(V0::Form21p530aController).to receive(:build_claim).and_raise(
          StandardError,
          'Unexpected error'
        )
        metrics = capture_statsd_calls do
          post(
            '/v0/form21p530a',
            params: form_data,
            headers: {
              'Content-Type' => 'application/json',
              'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
            }
          )
        end
        expect(response).to have_http_status(:internal_server_error)
        expect(metrics.collect(&:source)).to include(
          'api.form21p530a.failure:1|c',
          'api.rack.request:1|c|#controller:v0/form21p530a,action:create,source_app:21p-530a-interment-allowance,' \
          'status:500'
        )
      end
    end
  end

  describe 'GET /v0/form21p530a/download_pdf' do
    context 'when valid form data provided' do
      it 'returns a success' do
        metrics = capture_statsd_calls do
          post('/v0/form21p530a/download_pdf',
               params: form_data,
               headers: {
                 'Content-Type' => 'application/json',
                 'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
               })
        end
        expect(response).to have_http_status(:ok)
        expect(metrics.collect(&:source)).to include(
          'api.rack.request:1|c|#controller:v0/form21p530a,action:download_pdf,' \
          'source_app:21p-530a-interment-allowance,status:200'
        )
        expect(response.content_type).to eq('application/pdf')
      end
    end

    context 'when invalid form data provided' do
      let(:form_data) { Rails.root.join('spec', 'fixtures', 'form21p530a', 'invalid_form.json').read }

      it 'returns unprocessable_entity' do
        metrics = capture_statsd_calls do
          post('/v0/form21p530a/download_pdf',
               params: form_data,
               headers: {
                 'Content-Type' => 'application/json',
                 'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
               })
        end
        expect(response).to have_http_status(:unprocessable_entity)

        expect(metrics.collect(&:source)).to include(
          'api.rack.request:1|c|#controller:v0/form21p530a,action:download_pdf,' \
          'source_app:21p-530a-interment-allowance,status:422'
        )
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
    end
  end

  context 'when fill_ancillary_form raises an error' do
    it 'returns 500' do
      allow(PdfFill::Filler).to receive(:fill_ancillary_form).and_raise(StandardError, 'PDF generation error')

      metrics = capture_statsd_calls do
        post('/v0/form21p530a/download_pdf',
             params: form_data,
             headers: {
               'Content-Type' => 'application/json',
               'HTTP_SOURCE_APP_NAME' => '21p-530a-interment-allowance'
             })
      end
      expect(response).to have_http_status(:internal_server_error)
      expect(metrics.collect(&:source)).to include(
        'api.rack.request:1|c|#controller:v0/form21p530a,action:download_pdf,' \
        'source_app:21p-530a-interment-allowance,status:500'
      )

      expect(response).to have_http_status(:internal_server_error)
      expect(JSON.parse(response.body)['errors']).to be_present
      expect(JSON.parse(response.body)['errors'].first['status']).to eq('500')
    end
  end
end
