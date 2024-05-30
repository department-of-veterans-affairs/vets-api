# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'
require 'support/form1010_ezr/shared_examples/post_fill_user_form_field'

RSpec.describe Form1010Ezr::Service do
  include SchemaMatchers

  before do
    Flipper.disable(:ezr_async)
  end

  let(:form) { get_fixture('form1010_ezr/valid_form') }
  let(:current_user) do
    build(
      :evss_user,
      :loa3,
      icn: '1013032368V065534',
      birth_date: '1986-01-02',
      first_name: 'FirstName',
      middle_name: 'MiddleName',
      last_name: 'ZZTEST',
      suffix: 'Jr.',
      ssn: '111111234'
    )
  end
  let(:service) { described_class.new(current_user) }

  def allow_logger_to_receive_error
    allow(Rails.logger).to receive(:error)
  end

  def allow_logger_to_receive_info
    allow(Rails.logger).to receive(:info)
  end

  def expect_logger_errors(error_messages = [])
    error_messages.each do |e|
      expect(Rails.logger).to have_received(:error).with(include(e))
    end
  end

  def submit_form(form)
    described_class.new(current_user).submit_form(form)
  end

  describe '#add_financial_flag' do
    context 'when the form has veteran gross income' do
      let(:parsed_form) do
        {
          'veteranGrossIncome' => 100
        }
      end

      it 'adds the financial_flag' do
        expect(service.send(:add_financial_flag, parsed_form)).to eq(
          parsed_form.merge('discloseFinancialInformation' => true)
        )
      end
    end

    context 'when the form doesnt have veteran gross income' do
      it 'doesnt add the financial_flag' do
        expect(service.send(:add_financial_flag, {})).to eq({})
      end
    end
  end

  describe '#post_fill_veteran_full_name' do
    it_behaves_like 'post-fill user form field' do
      let(:klass_method) { 'post_fill_veteran_full_name' }
      let(:_parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'John',
            'middle' => 'Matthew',
            'last' => 'Smith',
            'suffix' => 'Sr.'
          }
        }
      end
      let(:statsd_increment_name) { 'missing_full_name' }
      let(:user_field) { 'veteranFullName' }
      let(:user_data) { current_user.full_name_normalized.compact.stringify_keys }
    end
  end

  describe '#post_fill_veteran_ssn' do
    it_behaves_like 'post-fill user form field' do
      let(:klass_method) { 'post_fill_veteran_ssn' }
      let(:_parsed_form) do
        {
          'veteranSocialSecurityNumber' => '111111234'
        }
      end
      let(:statsd_increment_name) { 'missing_ssn' }
      let(:user_field) { 'veteranSocialSecurityNumber' }
      let(:user_data) { current_user.ssn_normalized }
    end
  end

  describe '#post_fill_veteran_date_of_birth' do
    it_behaves_like 'post-fill user form field' do
      let(:klass_method) { 'post_fill_veteran_date_of_birth' }
      let(:_parsed_form) do
        {
          'veteranDateOfBirth' => '1985-04-03'
        }
      end
      let(:statsd_increment_name) { 'missing_date_of_birth' }
      let(:user_field) { 'veteranDateOfBirth' }
      let(:user_data) { current_user.birth_date }
    end
  end

  describe '#submit_form' do
    context 'with ezr_async on' do
      before do
        Flipper.enable(:ezr_async)
      end

      it 'submits the ezr with a background job', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          match_requests_on: %i[method uri body],
          erb: true,
          allow_unused_http_interactions: false
        ) do
          expect { submit_form(form) }.to change {
            HCA::EzrSubmissionJob.jobs.size
          }.by(1)

          HCA::EzrSubmissionJob.drain
        end
      end
    end

    context 'when successful' do
      before do
        allow_logger_to_receive_info
      end

      it "returns an object that includes 'success', 'formSubmissionId', and 'timestamp'",
         run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          # The required fields for the Enrollment System should be absent from the form data initially
          # and then added via the 'post_fill_required_fields' method
          expect(form['isEssentialAcaCoverage']).to eq(nil)
          expect(form['vaMedicalFacility']).to eq(nil)
          # If the 'veteranDateOfBirth', 'veteranFullName', and/or 'veteranSocialSecurityNumber' fields are missing
          # from the parsed_form, they should get added in via the 'post_fill_user_fields' method and pass validation
          form.delete('veteranDateOfBirth')
          form.delete('veteranFullName')
          form.delete('veteranSocialSecurityNumber')

          submission_response = submit_form(form)

          expect(submission_response).to be_a(Object)
          expect(submission_response).to eq(
            {
              success: true,
              formSubmissionId: 432_775_981,
              timestamp: '2023-11-21T14:42:44.858-06:00'
            }
          )
        end
      end

      it 'logs the submission id and payload size', run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          submission_response = submit_form(form)

          expect(Rails.logger).to have_received(:info).with("SubmissionID=#{submission_response[:formSubmissionId]}")
          expect(Rails.logger).to have_received(:info).with('Payload for submitted 1010EZR: ' \
                                                            'Body size of 12.1 KB with 0 attachment(s)')
        end
      end

      context 'when the form includes a Mexican province' do
        let(:form) { get_fixture('form1010_ezr/valid_form_with_mexican_province') }

        it "overrides the original province 'state' with the correct province initial and renders a " \
           'successful response', run_at: 'Tue, 21 Nov 2023 22:29:52 GMT' do
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
                formSubmissionId: 432_777_930,
                timestamp: '2023-11-21T16:29:52.432-06:00'
              }
            )
          end
        end
      end

      context 'when the form includes next of kin and/or emergency contact info' do
        let(:form) { get_fixture('form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact') }

        it 'returns a success object', run_at: 'Thu, 30 Nov 2023 15:52:36 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit_with_next_of_kin_and_emergency_contact',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            expect(submit_form(form)).to eq(
              {
                success: true,
                formSubmissionId: 432_861_975,
                timestamp: '2023-11-30T09:52:37.290-06:00'
              }
            )
          end
        end
      end

      context 'when the form includes TERA info' do
        let(:form) { get_fixture('form1010_ezr/valid_form_with_tera') }

        it 'returns a success object', run_at: 'Wed, 13 Mar 2024 18:14:49 GMT' do
          VCR.use_cassette(
            'form1010_ezr/authorized_submit_with_tera',
            { match_requests_on: %i[method uri body], erb: true }
          ) do
            expect(submit_form(form)).to eq(
              {
                success: true,
                formSubmissionId: 433_956_488,
                timestamp: '2024-03-13T13:14:50.252-05:00'
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
          expect_logger_errors(
            [
              '10-10EZR form validation failed. Form does not match schema.',
              "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
            ]
          )
        end

        it 'increments statsd' do
          allow(StatsD).to receive(:increment)

          expect(StatsD).to receive(:increment).with('api.1010ezr.submit_sync.fail',
                                                     tags: ['error:VCRErrorsUnhandledHTTPRequestError'])
          expect(StatsD).to receive(:increment).with('api.1010ezr.submit_sync.total')

          expect do
            submit_form(form)
          end.to raise_error(StandardError)
        end

        # REMOVE THIS TEST ONCE THE DOB ISSUE HAS BEEN DIAGNOSED - 3/27/24
        context "when the error pertains to the Veteran's DOB" do
          before do
            allow(JSON::Validator).to receive(:fully_validate).and_return(['veteranDateOfBirth error'])
          end

          it 'adds to the PersonalInformationLog and saves the unprocessed DOB' do
            expect { submit_form(form) }.to raise_error do |e|
              personal_information_log =
                PersonalInformationLog.find_by(error_class: "Form1010Ezr 'veteranDateOfBirth' schema failure")

              expect(personal_information_log.present?).to eq(true)
              expect(personal_information_log.data).to eq(form['veteranDateOfBirth'])
              expect(e).to be_a(Common::Exceptions::SchemaValidationErrors)
            end
          end
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
          expect_logger_errors(
            ['10-10EZR form submission failed: Uh oh. Some bad error occurred.']
          )
        end
      end
    end
  end
end
