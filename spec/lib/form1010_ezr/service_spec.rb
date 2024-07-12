# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'

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
      ssn: '111111234',
      gender: 'F'
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

  def ezr_form_with_attachments
    form.merge(
      'attachments' => [
        {
          'confirmationCode' => create(:form1010_ezr_attachment).guid
        },
        {
          'confirmationCode' => create(:form1010_ezr_attachment).guid
        }
      ]
    )
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

  describe '#post_fill_required_user_fields' do
    let(:required_user_fields) do
      {
        'veteranDateOfBirth' => current_user.birth_date,
        'veteranFullName' => current_user.full_name_normalized&.compact&.stringify_keys,
        'veteranSocialSecurityNumber' => current_user.ssn_normalized,
        'gender' => current_user.gender
      }
    end

    context 'when the fields are already present in the form' do
      let(:parsed_form) do
        {
          'veteranFullName' => {
            'first' => 'John',
            'middle' => 'Matthew',
            'last' => 'Smith',
            'suffix' => 'Sr.'
          },
          'veteranDateOfBirth' => '1991-01-06',
          'veteranSocialSecurityNumber' => '123456789',
          'gender' => 'M'
        }
      end

      it 'does not update the form fields' do
        service.send(:post_fill_required_user_fields, parsed_form)

        required_user_fields.each do |key, value|
          expect(parsed_form[key]).not_to eq(value)
        end
      end
    end

    context 'when one or more fields are not present, but the field(s) are present in the user session' do
      let(:parsed_form) { {} }

      before do
        allow(StatsD).to receive(:increment)
      end

      it "increments StatsD and adds/updates the form field(s) to be equal to the current_user's data" do
        required_user_fields.each_key do |key|
          expect(StatsD).to receive(:increment).with("api.1010ezr.missing_#{key.underscore}")
        end

        service.send(:post_fill_required_user_fields, parsed_form)

        required_user_fields.each do |key, value|
          expect(parsed_form[key]).to eq(value)
        end
      end
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
          # If the 'veteranDateOfBirth', 'veteranFullName', 'veteranSocialSecurityNumber', and/or 'gender' fields are
          # missing from the parsed_form, they should get added in via the 'post_fill_user_fields' method and
          # pass validation
          %w[veteranDateOfBirth veteranFullName veteranSocialSecurityNumber gender].each { |key| form.delete(key) }

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

      it 'logs the submission id, payload size, and individual attachment sizes in descending order (if applicable)',
         run_at: 'Tue, 18 Jun 2024 18:17:40 GMT' do
        VCR.use_cassette(
          'form1010_ezr/authorized_submit_with_attachments',
          { match_requests_on: %i[method uri body], erb: true }
        ) do
          submission_response = submit_form(ezr_form_with_attachments)

          expect(Rails.logger).to have_received(:info).with("SubmissionID=#{submission_response[:formSubmissionId]}")
          expect(Rails.logger).to have_received(:info).with('Payload for submitted 1010EZR: ' \
                                                            'Body size of 15.6 KB with 2 attachment(s)')
          expect(Rails.logger).to have_received(:info).with(
            'Attachment sizes in descending order: 1.8 KB, 1.8 KB'
          )
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

      context 'submitting with attachments' do
        let(:form) { get_fixture('form1010_ezr/valid_form') }

        context 'with pdf attachments' do
          it 'returns a success object', run_at: 'Tue, 18 Jun 2024 18:17:40 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_attachments',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              expect(submit_form(ezr_form_with_attachments)).to eq(
                {
                  success: true,
                  formSubmissionId: 435_240_209,
                  timestamp: '2024-06-18T13:17:40.593-05:00'
                }
              )
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZR: Body size of 15.6 KB with 2 attachment(s)'
              )
            end
          end
        end

        context 'with a non-pdf attachment' do
          it 'returns a success object', run_at: 'Tue, 18 Jun 2024 18:42:09 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_non_pdf_attachment',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              ezr_attachment = build(:form1010_ezr_attachment)
              ezr_attachment.set_file_data!(
                Rack::Test::UploadedFile.new(
                  'spec/fixtures/files/sm_file1.jpg',
                  'image/jpeg'
                )
              )
              ezr_attachment.save!

              form_with_non_pdf_attachment = form.merge(
                'attachments' => [
                  {
                    'confirmationCode' => ezr_attachment.guid
                  }
                ]
              )

              expect(submit_form(form_with_non_pdf_attachment)).to eq(
                {
                  success: true,
                  formSubmissionId: 435_240_322,
                  timestamp: '2024-06-18T13:42:09.475-05:00'
                }
              )
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZR: Body size of 12.8 KB with 1 attachment(s)'
              )
            end
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
