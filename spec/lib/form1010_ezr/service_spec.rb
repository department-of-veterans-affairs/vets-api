# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'

RSpec.describe Form1010Ezr::Service do
  include SchemaMatchers

  let(:form) { get_fixture('form1010_ezr/valid_form') }
  let(:current_user) { build(:evss_user, :loa3, icn: '1013032368V065534') }

  def allow_logger_to_receive_error
    allow(Rails.logger).to receive(:error)
  end

  def expect_logger_error(error_message)
    expect(Rails.logger).to have_received(:error).with(error_message)
  end

  def submit_form(form)
    described_class.new(current_user).submit_form(form)
  end

  describe '#submit_form' do
    context 'when successful' do
      it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'",
         run_at: 'Mon, 23 Oct 2023 23:09:43 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          # The required fields for the Enrollment System should be absent from the form data initially
          # and then added via the 'post_fill_required_fields' method
          expect(form['isEssentialAcaCoverage']).to eq(nil)
          expect(form['vaMedicalFacility']).to eq(nil)

          submission_response = submit_form(form)

          expect(submission_response).to be_a(Object)
          expect(submission_response).to eq(
            {
              success: true,
              formSubmissionId: 432_236_891,
              timestamp: '2023-10-23T18:12:24.628-05:00'
            }
          )
        end
      end

      context 'when the form includes a Mexican province' do
        let(:form) { get_fixture('form1010_ezr/valid_form_with_mexican_province') }

        it "overrides the original province 'state' with the correct province initial and renders a " \
           'successful response', run_at: 'Mon, 23 Oct 2023 23:42:13 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit_with_mexican_province',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            # The initial form data should include the JSON schema Mexican provinces before they're overridden
            expect(form['veteranAddress']['state']).to eq('chihuahua')
            expect(form['veteranHomeAddress']['state']).to eq('chihuahua')
            expect(submit_form(form)).to eq(
              {
                success: true,
                formSubmissionId: 432_236_923,
                timestamp: '2023-10-23T18:42:52.975-05:00'
              }
            )
          end
        end
      end
    end

    context 'when an error occurs' do
      context 'schema validation failure' do
        before do
          allow_logger_to_receive_error
          allow_any_instance_of(
            HCA::EnrollmentEligibility::Service
          ).to receive(:lookup_user).and_return({ preferred_facility: '988' })
        end

        it 'logs and raises a schema validation error' do
          form_sans_required_field = form.except('privacyAgreementAccepted')

          expect(StatsD).to receive(:increment).with('api.1010ezr.validation_error')
          expect(StatsD).to receive(:increment).with('api.1010ezr.failed_wont_retry')

          expect { submit_form(form_sans_required_field) }.to raise_error do |e|
            expect(e).to be_a(Common::Exceptions::SchemaValidationErrors)
            expect(e.errors[0].title).to eq('Validation error')
            expect(e.errors[0].detail).to include(
              "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
            )
            expect(e.errors[0].status).to eq('422')
          end
          expect_logger_error('10-10EZR form validation failed. Form does not match schema.')
        end
      end

      context 'any other error' do
        before do
          allow_any_instance_of(
            Common::Client::Base
          ).to receive(:perform).and_raise(
            StandardError.new('Uh oh. Some bad error occurred.')
          )
          allow_logger_to_receive_error
        end

        it 'logs and raises the error' do
          expect do
            submit_form(form)
          end.to raise_error(
            StandardError, 'Uh oh. Some bad error occurred.'
          )
          expect_logger_error('10-10EZR form submission failed: Uh oh. Some bad error occurred.')
        end
      end
    end
  end
end
