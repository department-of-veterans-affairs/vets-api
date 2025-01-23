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
end
