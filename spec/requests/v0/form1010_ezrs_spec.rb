# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'V0::Form1010Ezrs', type: :request do
  let(:form) do
    File.read('spec/fixtures/form1010_ezr/valid_form.json')
  end

  describe 'POST create' do
    subject do
      post(
        v0_form1010_ezrs_path,
        params: params.to_json,
        headers: {
          'CONTENT_TYPE' => 'application/json',
          'HTTP_X_KEY_INFLECTION' => 'camel'
        }
      )
    end

    context 'while unauthenticated' do
      let(:params) do
        { form: }
      end

      it 'returns an error in the response body' do
        subject

        expect(response).to have_http_status(:unauthorized)
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('Not authorized')
      end
    end

    context 'while authenticated', :skip_mvi do
      let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

      before do
        sign_in_as(current_user)
      end

      context 'when no error occurs' do
        let(:params) do
          { form: }
        end
        let(:body) do
          {
            'formSubmissionId' => nil,
            'timestamp' => nil,
            'success' => true
          }
        end

        it 'increments statsd' do
          expect { subject }.to trigger_statsd_increment('api.1010ezr.submission_attempt')
        end

        it 'renders a successful response and deletes the saved form' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit_async',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('10-10EZR').once
            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end
    end
  end

  describe 'GET veteran_prefill_data' do
    context 'while unauthenticated' do
      it 'returns an unauthenticated error' do
        get(veteran_prefill_data_v0_form1010_ezrs_path)

        expect(response).to have_http_status(:unauthorized)
        expect(response.body).to include('Not authorized')
      end
    end

    context 'while authenticated', :skip_mvi do
      let(:prefill_data) { JSON.parse(File.read('spec/fixtures/form1010_ezr/veteran_prefill_data.json')) }
      let(:current_user) { build(:evss_user, :loa3, icn: '1012829228V424035') }

      before do
        sign_in_as(current_user)
      end

      context 'when no error occurs' do
        it 'renders a successful JSON response with Veteran prefill data', run_at: 'Thu, 27 Feb 2025 01:10:06 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_veteran_prefill_data',
            match_requests_on: %i[method uri body], erb: true
          ) do
            get(veteran_prefill_data_v0_form1010_ezrs_path)

            expect(JSON.parse(response.body)['data']).to eq(prefill_data)
          end
        end
      end
    end
  end
end
