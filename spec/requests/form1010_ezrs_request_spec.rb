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
        expect(JSON.parse(response.body)['errors'][0]['detail']).to eq('Not authorized')
      end
    end

    context 'while authenticated', skip_mvi: true do
      let(:current_user) { build(:evss_user, :loa3) }

      before do
        sign_in_as(current_user)
        allow(current_user).to receive(:icn).and_return('1013032368V065534')
      end

      context 'when no error occurs' do
        let(:params) do
          { form: }
        end
        let(:body) do
          {
            'formSubmissionId' => 432_236_891,
            'timestamp' => '2023-10-23T18:12:24.628-05:00',
            'success' => true
          }
        end

        it 'renders a successful response and deletes the saved form', run_at: 'Mon, 23 Oct 2023 23:09:43 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit',
            match_requests_on: [:method]
          ) do
            # The required fields for the Enrollment System should be absent from the form data initially
            # and then added via the 'post_fill_required_fields' method
            expect(params[:form].to_json['isEssentialAcaCoverage']).to eq(nil)
            expect(params[:form].to_json['vaMedicalFacility']).to eq(nil)
            expect_any_instance_of(ApplicationController).to receive(:clear_saved_form).with('10-10EZR').once
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

        before do
          allow_any_instance_of(
            HCA::EnrollmentEligibility::Service
          ).to receive(:lookup_user).and_return({ preferred_facility: '988' })
        end

        it 'returns an error in the response body' do
          subject

          response_error = JSON.parse(response.body)['errors'][0]

          expect(response_error['status']).to eq('422')
          expect(
            response_error['detail'].include?(
              "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
            )
          ).to eq(true)
        end
      end
    end
  end
end
