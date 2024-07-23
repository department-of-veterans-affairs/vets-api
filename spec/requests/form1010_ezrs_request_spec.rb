# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Form1010 Ezrs', type: :request do
  let(:form) do
    File.read('spec/fixtures/form1010_ezr/valid_form.json')
  end

  before do
    Flipper.disable(:ezr_async)
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
            'formSubmissionId' => 432_775_981,
            'timestamp' => '2023-11-21T14:42:44.858-06:00',
            'success' => true
          }
        end

        it 'renders a successful response and deletes the saved form', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
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

        it 'increments statsd' do
          expect { subject }.to trigger_statsd_increment('api.1010ezr.submission_attempt')
        end

        context 'when the form includes a Mexican province' do
          let(:params) do
            {
              form: File.read('spec/fixtures/form1010_ezr/valid_form_with_mexican_province.json')
            }
          end
          let(:body) do
            {
              'formSubmissionId' => 432_777_930,
              'timestamp' => '2023-11-21T16:29:52.432-06:00',
              'success' => true
            }
          end

          it "overrides the original province 'state' with the correct province initial and renders a " \
             'successful response', run_at: 'Tue, 21 Nov 2023 22:29:52 GMT' do
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

        context 'when the form includes next of kin and/or emergency contact info' do
          let(:params) do
            {
              form: File.read('spec/fixtures/form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact.json')
            }
          end
          let(:body) do
            {
              'formSubmissionId' => 432_861_975,
              'timestamp' => '2023-11-30T09:52:37.290-06:00',
              'success' => true
            }
          end

          it 'returns a successful response object', run_at: 'Thu, 30 Nov 2023 15:52:36 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_next_of_kin_and_emergency_contact',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              subject

              expect(JSON.parse(response.body)).to eq(body)
            end
          end
        end

        context 'when the form includes TERA info' do
          let(:params) do
            {
              form: File.read('spec/fixtures/form1010_ezr/valid_form_with_tera.json')
            }
          end
          let(:body) do
            {
              'formSubmissionId' => 433_956_488,
              'timestamp' => '2024-03-13T13:14:50.252-05:00',
              'success' => true
            }
          end

          it 'returns a successful response object', run_at: 'Wed, 13 Mar 2024 18:14:49 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_tera',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              subject

              expect(JSON.parse(response.body)).to eq(body)
            end
          end
        end

        context 'when ezr_async is on' do
          before do
            Flipper.enable(:ezr_async)
          end

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
