# frozen_string_literal: true

require 'rails_helper'
require 'form1010_ezr/service'
require 'form1010_ezr/veteran_enrollment_system/associations/service'

RSpec.describe Form1010Ezr::Service do
  include SchemaMatchers

  let(:form) { get_fixture('form1010_ezr/valid_form') }
  let(:ves_fields) do
    {
      'discloseFinancialInformation' => true,
      'isEssentialAcaCoverage' => false,
      'vaMedicalFacility' => '988'
    }
  end
  let(:form_with_ves_fields) { form.merge!(ves_fields) }
  let(:current_user) do
    create(
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
    form_with_ves_fields.merge(
      'attachments' => [
        {
          'confirmationCode' => create(:form1010_ezr_attachment).guid
        },
        {
          'confirmationCode' => create(:form1010_ezr_attachment2).guid
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

  describe '#post_fill_required_fields' do
    it 'Adds required fields in the Enrollment System API to the form object',
       run_at: 'Fri, 08 Feb 2019 02:50:45 GMT' do
      VCR.use_cassette(
        'hca/ee/lookup_user',
        VCR::MATCH_EVERYTHING.merge(erb: true)
      ) do
        expect(form.keys).not_to include('isEssentialAcaCoverage', 'vaMedicalFacility')

        service.send(:post_fill_required_fields, form)

        expect(form.keys).to include('isEssentialAcaCoverage', 'vaMedicalFacility')
        expect(form['isEssentialAcaCoverage']).to be(false)
        expect(form['vaMedicalFacility']).to eq('988')
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

  describe '#log_submission_failure_to_sentry' do
    it 'logs a failure message to sentry' do
      expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
        '1010EZR failure',
        :error,
        {
          first_initial: 'F',
          middle_initial: 'M',
          last_initial: 'Z'
        },
        ezr: :failure
      )

      described_class.log_submission_failure_to_sentry(form, '1010EZR failure', 'failure')
    end
  end

  # Loop through the tests and run them once with the 'va1010_forms_enrollment_system_service_enabled'
  # flipper enabled and then once disabled
  [1, 2].each do |i|
    describe '#submit_form' do
      before do
        Flipper.disable(:va1010_forms_enrollment_system_service_enabled) if i == 2
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

      context 'when an error occurs' do
        let(:current_user) do
          create(
            :evss_user,
            :loa3,
            icn: '1013032368V065534',
            birth_date: nil,
            first_name: nil,
            middle_name: nil,
            last_name: 'test',
            suffix: nil,
            ssn: nil,
            gender: nil
          )
        end

        context 'schema validation failure' do
          before do
            allow_logger_to_receive_error
            allow_any_instance_of(
              HCA::EnrollmentEligibility::Service
            ).to receive(:lookup_user).and_return({ preferred_facility: '988' })
          end

          it 'logs and raises a schema validation error' do
            form_sans_required_fields = form.except(
              'privacyAgreementAccepted',
              'veteranDateOfBirth',
              'veteranFullName',
              'veteranSocialSecurityNumber',
              'gender'
            )

            allow(StatsD).to receive(:increment)

            expect(StatsD).to receive(:increment).with('api.1010ezr.validation_error')
            expect { submit_form(form_sans_required_fields) }.to raise_error do |e|
              expect(e).to be_a(Common::Exceptions::SchemaValidationErrors)
              expect(e.errors.length).to eq(6)
              e.errors.each do |error|
                expect(error.title).to eq('Validation error')
                expect(error.status).to eq('422')
              end
            end
            expect_logger_errors(
              [
                '10-10EZR form validation failed. Form does not match schema.',
                "The property '#/veteranFullName' did not contain a required property of 'first'",
                "The property '#/veteranDateOfBirth' of type null did not match the following type: string",
                "The property '#/veteranSocialSecurityNumber' of type null did not match the following type: string",
                "The property '#/gender' of type null did not match the following type: string",
                "The property '#/' did not contain a required property of 'privacyAgreementAccepted'"
              ]
            )
          end

          # REMOVE THIS TEST ONCE THE DOB ISSUE HAS BEEN DIAGNOSED - 3/27/24
          context "when the error pertains to the Veteran's DOB" do
            before do
              allow(JSON::Validator).to receive(:fully_validate).and_return(['veteranDateOfBirth error'])
            end

            it 'creates a PersonalInformationLog and saves the unprocessed DOB' do
              expect { submit_form(form) }.to raise_error do |e|
                personal_information_log =
                  PersonalInformationLog.find_by(error_class: "Form1010Ezr 'veteranDateOfBirth' schema failure")

                expect(personal_information_log.present?).to be(true)
                expect(personal_information_log.data).to eq(form['veteranDateOfBirth'])
                expect(e).to be_a(Common::Exceptions::SchemaValidationErrors)
              end
            end
          end
        end

        context "when the 'ezr_associations_api_enabled' flipper is enabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_associations_api_enabled).and_return(true)
          end

          context 'when an error occurs in the associations service' do
            before do
              allow_any_instance_of(
                Form1010Ezr::VeteranEnrollmentSystem::Associations::Service
              ).to receive(:get_associations).and_raise(
                Common::Exceptions::ResourceNotFound.new(
                  detail: 'associations[0].relationType: Relation type is required'
                )
              )
            end

            it 'increments statsD, logs the error to sentry, and raises the error',
               run_at: 'Tue, 21 Nov 2023 20:42:44 GMT' do
              VCR.use_cassette(
                'form1010_ezr/authorized_submit',
                { match_requests_on: %i[method uri body], erb: true }
              ) do
                allow(StatsD).to receive(:increment)

                expect(StatsD).to receive(:increment).with('api.1010ezr.failed')
                expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
                  '1010EZR failure',
                  :error,
                  {
                    first_initial: 'F',
                    middle_initial: 'M',
                    last_initial: 'Z'
                  },
                  ezr: :failure
                )
                expect { submit_form(form) }.to raise_error(Common::Exceptions::ResourceNotFound).and(
                  having_attributes(detail: 'associations[0].relationType: Relation type is required')
                )
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

          it 'increments StatsD, logs the message to sentry, and raises the error' do
            allow(StatsD).to receive(:increment)

            expect(StatsD).to receive(:increment).with('api.1010ezr.failed')
            expect_any_instance_of(SentryLogging).to receive(:log_message_to_sentry).with(
              '1010EZR failure',
              :error,
              {
                first_initial: 'F',
                middle_initial: 'M',
                last_initial: 'Z'
              },
              ezr: :failure
            )

            expect { submit_form(form) }.to raise_error(
              StandardError, 'Uh oh. Some bad error occurred.'
            )
          end
        end
      end
    end

    describe '#submit_sync' do
      context 'when an error occurs' do
        it 'increments statsd' do
          allow(StatsD).to receive(:increment)

          expect(StatsD).to receive(:increment).with(
            'api.1010ezr.submit_sync.fail',
            tags: ['error:VCRErrorsUnhandledHTTPRequestError']
          )
          expect(StatsD).to receive(:increment).with('api.1010ezr.submit_sync.total')
          expect { service.submit_sync(form_with_ves_fields) }.to raise_error(StandardError)
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
            submission_response = service.submit_sync(form_with_ves_fields)

            expect(submission_response).to be_a(Object)
            expect(submission_response).to eq(
              {
                success: true,
                formSubmissionId: 436_462_561,
                timestamp: '2024-08-23T13:00:11.005-05:00'
              }
            )
          end
        end

        context "with the 'ezr_use_correct_format_for_file_uploads' flipper enabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(true)
          end

          it "logs the submission id, user's initials, payload size, and individual attachment sizes in descending " \
             'order (if applicable)',
             run_at: 'Wed, 12 Feb 2025 18:40:51 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_attachments_formatted_correctly',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              submission_response = service.submit_sync(ezr_form_with_attachments)

              expect(Rails.logger).to have_received(:info).with(
                '1010EZR successfully submitted',
                submission_id: submission_response[:formSubmissionId],
                veteran_initials: {
                  first_initial: 'F',
                  middle_initial: 'M',
                  last_initial: 'Z'
                }
              )
              expect(Rails.logger).to have_received(:info).with(
                'Payload for submitted 1010EZR: Body size of 362 KB with 2 attachment(s)'
              )
              expect(Rails.logger).to have_received(:info).with(
                'Attachment sizes in descending order: 348 KB, 1.8 KB'
              )
            end
          end
        end

        context 'when the form includes a Mexican province' do
          let(:form) do
            get_fixture('form1010_ezr/valid_form_with_mexican_province').merge!(ves_fields)
          end

          it 'returns a success object', run_at: 'Tue, 21 Nov 2023 22:29:52 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_mexican_province',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              overridden_form = HCA::OverridesParser.new(form).override

              expect(service.submit_sync(overridden_form)).to eq(
                {
                  success: true,
                  formSubmissionId: 436_460_791,
                  timestamp: '2024-08-23T11:49:44.562-05:00'
                }
              )
            end
          end
        end

        context 'when the form includes next of kin and/or emergency contact info' do
          let(:form) do
            get_fixture(
              'form1010_ezr/valid_form_with_next_of_kin_and_emergency_contact'
            ).merge!(ves_fields)
          end

          it 'returns a success object', run_at: 'Thu, 30 Nov 2023 15:52:36 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_next_of_kin_and_emergency_contact',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              expect(service.submit_sync(form)).to eq(
                {
                  success: true,
                  formSubmissionId: 436_462_887,
                  timestamp: '2024-08-23T13:22:29.157-05:00'
                }
              )
            end
          end
        end

        context 'when the form includes TERA info' do
          let(:form) do
            get_fixture('form1010_ezr/valid_form_with_tera').merge!(ves_fields)
          end

          it 'returns a success object', run_at: 'Wed, 13 Mar 2024 18:14:49 GMT' do
            VCR.use_cassette(
              'form1010_ezr/authorized_submit_with_tera',
              { match_requests_on: %i[method uri body], erb: true }
            ) do
              expect(service.submit_sync(form)).to eq(
                {
                  success: true,
                  formSubmissionId: 436_462_892,
                  timestamp: '2024-08-23T13:22:59.196-05:00'
                }
              )
            end
          end
        end

        context 'submitting with attachments' do
          let(:form) { get_fixture('form1010_ezr/valid_form') }

          context "with the 'ezr_use_correct_format_for_file_uploads' flipper enabled" do
            before do
              allow(Flipper).to receive(:enabled?).and_call_original
              allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(true)
            end

            context 'with pdf attachments' do
              it 'increments StatsD and returns a success object', run_at: 'Wed, 12 Feb 2025 18:40:51 GMT' do
                allow(StatsD).to receive(:increment)
                expect(StatsD).to receive(:increment).with('api.1010ezr.submission_with_attachment')

                VCR.use_cassette(
                  'form1010_ezr/authorized_submit_with_attachments_formatted_correctly',
                  { match_requests_on: %i[method uri body], erb: true }
                ) do
                  expect(service.submit_sync(ezr_form_with_attachments)).to eq(
                    {
                      success: true,
                      formSubmissionId: 440_227_389,
                      timestamp: '2025-02-12T12:40:53.043-06:00'
                    }
                  )
                  expect(Rails.logger).to have_received(:info).with(
                    'Payload for submitted 1010EZR: Body size of 362 KB with 2 attachment(s)'
                  )
                end
              end
            end

            context 'with a non-pdf attachment' do
              it 'increments StatsD and returns a success object', run_at: 'Wed, 12 Feb 2025 19:00:16 GMT' do
                allow(StatsD).to receive(:increment)
                expect(StatsD).to receive(:increment).with('api.1010ezr.submission_with_attachment')

                VCR.use_cassette(
                  'form1010_ezr/authorized_submit_with_non_pdf_attachment_formatted_correctly',
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

                  form_with_non_pdf_attachment = form_with_ves_fields.merge(
                    'attachments' => [
                      {
                        'confirmationCode' => ezr_attachment.guid
                      }
                    ]
                  )

                  expect(service.submit_sync(form_with_non_pdf_attachment)).to eq(
                    {
                      success: true,
                      formSubmissionId: 440_227_675,
                      timestamp: '2025-02-12T13:00:17.891-06:00'
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

        context "with the 'ezr_use_correct_format_for_file_uploads' flipper disabled" do
          before do
            allow(Flipper).to receive(:enabled?).and_call_original
            allow(Flipper).to receive(:enabled?).with(:ezr_use_correct_format_for_file_uploads).and_return(false)
          end

          context 'with pdf attachments' do
            it 'increments StatsD and returns a success object', run_at: 'Wed, 17 Jul 2024 18:17:32 GMT' do
              allow(StatsD).to receive(:increment)
              expect(StatsD).to receive(:increment).with('api.1010ezr.submission_with_attachment')

              VCR.use_cassette(
                'form1010_ezr/authorized_submit_with_attachments',
                { match_requests_on: %i[method uri body], erb: true }
              ) do
                expect(service.submit_sync(ezr_form_with_attachments)).to eq(
                  {
                    success: true,
                    formSubmissionId: 436_462_804,
                    timestamp: '2024-08-23T13:20:06.967-05:00'
                  }
                )
                expect(Rails.logger).to have_received(:info).with(
                  'Payload for submitted 1010EZR: Body size of 362 KB with 2 attachment(s)'
                )
              end
            end
          end

          context 'with a non-pdf attachment' do
            it 'increments StatsD and returns a success object', run_at: 'Wed, 17 Jul 2024 18:17:34 GMT' do
              allow(StatsD).to receive(:increment)
              expect(StatsD).to receive(:increment).with('api.1010ezr.submission_with_attachment')

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

                form_with_non_pdf_attachment = form_with_ves_fields.merge(
                  'attachments' => [
                    {
                      'confirmationCode' => ezr_attachment.guid
                    }
                  ]
                )

                expect(service.submit_sync(form_with_non_pdf_attachment)).to eq(
                  {
                    success: true,
                    formSubmissionId: 436_462_905,
                    timestamp: '2024-08-23T13:23:53.956-05:00'
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
    end
  end
end
