# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'

RSpec.describe 'Form1010 Ezrs', type: :request do
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
        expect(
          JSON.parse(response.body)['errors'][0]['detail'].include?(
            'Missing user credentials'
          )
        ).to eq(true)
      end
    end

    context 'while authenticated', skip_mvi: true do
      let(:current_user) { build(:evss_user, :loa3) }

      before do
        sign_in_as(current_user)
      end

      context 'when no error occurs' do
        let(:params) do
          { form: }
        end
        let(:body) do
          {
            'formSubmissionId' => 432_137_192,
            'timestamp' => '2023-10-20T14:41:58.948-05:00',
            'success' => true
          }
        end

        it 'renders success and delete the saved form', run_at: 'Fri, 20 Oct 2023 19:41:58 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit',
            VCR::MATCH_EVERYTHING.merge(erb: true)
          ) do
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('1010ezr').once
            subject
            expect(JSON.parse(response.body)).to eq(body)
          end
        end
      end

      context 'when an error occurs' do
        let(:params) do
          {
            form: JSON.parse(form).except('privacyAgreementAccepted').to_json
          }
        end

        it 'shows the validation errors' do
          subject

          expect(response).to have_http_status(:bad_request)
          expect(
            JSON.parse(response.body)['errors'][0]['detail'].include?(
              'The Form1010Ezr service responded with something other than the expected submission object'
            )
          ).to eq(true)
        end
      end
    end
  end
end
