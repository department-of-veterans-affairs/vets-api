# frozen_string_literal: true

require 'rails_helper'

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
            'formSubmissionId' => 432_236_891,
            'timestamp' => '2023-10-23T18:12:24.628-05:00',
            'success' => true
          }
        end

        it 'renders a successful response and deletes the saved form', run_at: 'Mon, 23 Oct 2023 23:09:43 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit',
            { match_requests_on: %i[method uri body], erb: true }
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

        context 'when the form includes a Mexican province' do
          let(:params) do
            {
              form: File.read('spec/fixtures/form1010_ezr/valid_form_with_mexican_province.json')
            }
          end
          let(:body) do
            {
              'formSubmissionId' => 432_236_923,
              'timestamp' => '2023-10-23T18:42:52.975-05:00',
              'success' => true
            }
          end

          it "overrides the original province 'state' with the correct province initial and renders a " \
             'successful response', run_at: 'Mon, 23 Oct 2023 23:42:13 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_mexican_province',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              # The initial form data should include the JSON schema Mexican provinces before they're overridden
              expect(JSON.parse(params[:form])['veteranAddress']['state']).to eq('chihuahua')
              expect(JSON.parse(params[:form])['veteranHomeAddress']['state']).to eq('chihuahua')
              subject

              expect(JSON.parse(response.body)).to eq(body)
            end
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
