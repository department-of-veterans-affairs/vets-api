# frozen_string_literal: true

require 'rails_helper'
require 'hca/service'

RSpec.describe 'Form1010 Ezrs', type: :request do
  let(:test_veteran) do
    JSON.parse(File.read('spec/lib/form1010_ezr/support/valid_form.json'))
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
      it 'returns an error in the response body' do
        subject

        expect(response).to have_http_status(:unauthorized)
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'Missing user credentials'
          )
        ).to eq(true)
      end
    end

    context 'while authenticated', skip_mvi: true do
      let(:current_user) { build(:user, :mhv) }

      before do
        sign_in_as(current_user)
      end

      context 'when an error occurs' do
        let(:params) do
          {
            form: test_veteran.except('privacyAgreementAccepted').to_json
          }
        end

        it 'returns the error in the response body' do
          subject

          expect(response).to have_http_status(:bad_request)
          expect(
            JSON.parse(response.body)['errors'][0]['detail'].include?(
              'The Form1010Ezr service responded with something other than the expected submission object'
            )
          ).to eq(true)
        end
      end

      # context 'when no error occurs' do
      #   let(:params) do
      #     {
      #       form: test_veteran.to_json
      #     }
      #   end
      #   let(:body) do
      #     { 'formSubmissionId' => 40_125_311_094,
      #       'timestamp' => '2017-02-08T13:50:32.020-06:00',
      #       'success' => true }
      #   end
      #
      #   it 'renders success and delete the saved form', run_at: '2022-01-31' do
      #     VCR.use_cassette('hca/submit_auth', match_requests_on: [:body]) do
      #       expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('1010ez').once
      #       expect_any_instance_of(HealthCareApplication).to receive(:prefill_fields)
      #       subject
      #       expect(JSON.parse(response.body)).to eq(body)
      #     end
      #   end
      # end
    end
  end
end