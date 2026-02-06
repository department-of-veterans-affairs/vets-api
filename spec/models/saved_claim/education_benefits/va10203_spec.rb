# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'
require 'feature_flipper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { build(:va10203, education_benefits_claim: create(:education_benefits_claim)) }

  before do
    allow(Flipper).to receive(:enabled?).and_call_original
  end

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10203')

  describe '#in_progress_form_id' do
    it 'returns 22-10203' do
      expect(instance.in_progress_form_id).to eq('22-10203')
    end
  end

  describe '#after_submit' do
    context 'when form 10203 claimant flipper enabled' do
      before { allow(Flipper).to receive(:enabled?).with(:form_10203_claimant_service).and_return(true) }

      context 'when the user is logged in' do
        let(:user) { create(:user) }
        let(:service) { SOB::DGI::Service.new(ssn: user.ssn, include_enrollments: true) }

        before do
          allow(SOB::DGI::Service).to receive(:new).and_return(service)
          allow(service).to receive(:get_ch33_status).and_call_original
        end

        it 'calls get_ch33_status on the service' do
          VCR.use_cassette('sob/ch33_status/200_with_enrollments') do
            instance.after_submit(user)
            expect(service).to have_received(:get_ch33_status)
            expect(SOB::DGI::Service).to have_received(:new).with(ssn: user.ssn, include_enrollments: true)
                                                            .exactly(1).times
          end
        end

        it 'sets the gi_bill_status instance variable' do
          VCR.use_cassette('sob/ch33_status/200_with_enrollments') do
            instance.after_submit(user)
            expect(instance.instance_variable_get(:@gi_bill_status)).not_to be_nil
          end
        end

        context 'when get_ch33_status raises an error' do
          before do
            allow(Rails.logger).to receive(:error)
            allow(service).to receive(:get_ch33_status).and_raise(StandardError)
          end

          it 'logs an error' do
            instance.after_submit(user)
            expect(Rails.logger).to have_received(:error)
          end
        end

        context 'stem automated decision processing' do
          it 'creates education_stem_automated_decision for user' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision).not_to be_nil
            expect(instance.education_benefits_claim.education_stem_automated_decision.user_uuid)
              .to eq(user.uuid)
            expect(instance.education_benefits_claim.education_stem_automated_decision.user_account_id)
              .to eq(user.user_account.id)
            expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
          end

          it 'saves user auth_headers' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
          end

          it 'always sets POA to nil' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
          end
        end

        context 'sending the confirmation email' do
          context 'when the form21_10203_confirmation_email feature flag is disabled' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(false)
              expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
            end

            it 'does not call SendSchoolCertifyingOfficialsEmail' do
              expect { instance.after_submit(user) }
                .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            end
          end

          context 'when the form21_10203_confirmation_email feature flag is enabled' do
            before { allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true) }

            context 'when there is no form email' do
              it 'does not send a confirmation email' do
                allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                allow(VANotify::EmailJob).to receive(:perform_async)

                subject = instance
                form = JSON.parse(subject.form)
                form.delete('email')
                subject.form = form.to_json
                subject.after_submit(user)

                expect(VANotify::EmailJob).not_to have_received(:perform_async)
              end
            end

            context 'when there is a form email' do
              context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is disabled' do
                before do
                  allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                      .and_return(false)
                end

                it 'sends the confirmation email without the callback parameters' do
                  allow(VANotify::EmailJob).to receive(:perform_async)

                  instance.after_submit(user)

                  expect(VANotify::EmailJob).to have_received(:perform_async).with(
                    'test@sample.com',
                    'form21_10203_confirmation_email_template_id',
                    {
                      'first_name' => 'MARK',
                      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                      'confirmation_number' => instance.education_benefits_claim.confirmation_number,
                      'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                    }
                  )
                  allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                end
              end

              context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is enabled' do
                let(:callback_options) do
                  {
                    callback_metadata: {
                      notification_type: 'confirmation',
                      form_number: '22-10203',
                      statsd_tags: {
                        service: 'submit-10203-form', function: 'form_10203_failure_confirmation_email_sending'
                      }
                    }
                  }
                end

                before do
                  allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                      .and_return(true)
                end

                it 'sends the confirmation email with the form email with the callback paarameters' do
                  allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                  allow(VANotify::EmailJob).to receive(:perform_async)

                  subject = instance
                  subject.after_submit(user)

                  expect(VANotify::EmailJob).to have_received(:perform_async).with(
                    'test@sample.com',
                    'form21_10203_confirmation_email_template_id',
                    {
                      'first_name' => 'MARK',
                      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                      'confirmation_number' => subject.education_benefits_claim.confirmation_number,
                      'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                    },
                    Settings.vanotify.services.va_gov.api_key,
                    callback_options
                  )
                end
              end
            end
          end
        end

        context 'sending the school certifying officials email' do
          context 'when the send_email? FeatureFlipper is false' do
            before { allow(FeatureFlipper).to receive(:send_email?).and_return(false) }

            it 'does not call SendSchoolCertifyingOfficialsEmail' do
              expect { instance.after_submit(user) }
                .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
            end
          end

          context 'when the send_email? FeatureFlipper is true' do
            before { allow(FeatureFlipper).to receive(:send_email?).and_return(true) }

            context 'unauthorized' do
              before do
                allow(FeatureFlipper).to receive(:send_email?).and_return(true)
                expect(user).to receive(:authorize).with(:dgi, :access?).and_return(false).at_least(:once)
                expect(user.authorize(:dgi, :access?)).to be(false)
                mail = double('mail')
                allow(mail).to receive(:deliver_now)
                allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
              end

              it 'does not call SendSchoolCertifyingOfficialsEmail' do
                expect { instance.after_submit(user) }
                  .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
              end
            end

            context 'authorized' do
              before do
                expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
                expect(user).to receive(:authorize).with(:dgi, :access?).and_return(true).at_least(:once)
                expect(user.authorize(:dgi, :access?)).to be(true)
                mail = double('mail')
                allow(mail).to receive(:deliver_now)
                allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
                allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(false)
              end

              it 'increments the SendSchoolCertifyingOfficialsEmail job queue (calls the job)' do
                expect { instance.after_submit(user) }
                  .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(1)
              end

              it 'calls SendSchoolCertifyingOfficialsEmail with correct arguments (gibill status is {})' do
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)

                instance.after_submit(user)

                expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                  .to have_received(:perform_async)
                  .with(instance.id, false, {})
              end

              it 'calls SendSchoolCertifyingOfficialsEmail (remaining entitlement < 6 months)' do
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)
                VCR.use_cassette('sob/ch33_status/200_with_enrollments') do
                  instance.after_submit(user)

                  expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                    .to have_received(:perform_async)
                    .with(instance.id, true, '11902614')
                end
              end

              it 'calls SendSchoolCertifyingOfficialsEmail (remaining entitlement >= 6 months)' do
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)
                VCR.use_cassette('sob/ch33_status/200_with_enrollments_and_remaining_entitlement') do
                  instance.after_submit(user)

                  expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                    .to have_received(:perform_async)
                    .with(instance.id, false, '11902614')
                end
              end
            end
          end
        end
      end

      context 'Not logged in' do
        before do
          mail = double('mail')
          allow(mail).to receive(:deliver_now)
          allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
        end

        it 'does not set @gi_bill_status' do
          instance.after_submit(nil)
          expect(instance.instance_variable_get(:@gi_bill_status)).to be_nil
        end

        it 'does not create education_stem_automated_decision' do
          instance.after_submit(nil)
          expect(instance.education_benefits_claim.education_stem_automated_decision).to be_nil
        end

        it 'does not call SendSchoolCertifyingOfficialsEmail' do
          expect { instance.after_submit(nil) }
            .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
        end

        context 'when there is no form email' do
          it 'does not send a confirmation email' do
            allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = instance
            form = JSON.parse(subject.form)
            form.delete('email')
            subject.form = form.to_json
            subject.after_submit(nil)

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end

        context 'when there is a form email' do
          context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is disabled' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                  .and_return(false)
            end

            it 'sends the confirmation email without the callback parameters' do
              allow(VANotify::EmailJob).to receive(:perform_async)

              instance.after_submit(nil)

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'test@sample.com',
                'form21_10203_confirmation_email_template_id',
                {
                  'first_name' => 'MARK',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => instance.education_benefits_claim.confirmation_number,
                  'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                }
              )
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            end
          end

          context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is enabled' do
            let(:callback_options) do
              {
                callback_metadata: {
                  notification_type: 'confirmation',
                  form_number: '22-10203',
                  statsd_tags: { service: 'submit-10203-form',
                                 function: 'form_10203_failure_confirmation_email_sending' }
                }
              }
            end

            before do
              allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                  .and_return(true)
            end

            it 'sends the confirmation email with the form email with the callback paarameters' do
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
              allow(VANotify::EmailJob).to receive(:perform_async)

              subject = instance
              subject.after_submit(nil)

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'test@sample.com',
                'form21_10203_confirmation_email_template_id',
                {
                  'first_name' => 'MARK',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => subject.education_benefits_claim.confirmation_number,
                  'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                },
                Settings.vanotify.services.va_gov.api_key,
                callback_options
              )
            end
          end
        end
      end
    end

    context 'when form 10203 claimant flipper disabled' do
      before { allow(Flipper).to receive(:enabled?).with(:form_10203_claimant_service).and_return(false) }

      context 'when the user is logged in' do
        let(:user) { create(:user) }
        let(:service) { instance_double(BenefitsEducation::Service) }

        before do
          allow(BenefitsEducation::Service).to receive(:new).and_return(service)
          allow(service).to receive(:get_gi_bill_status).and_return({})
        end

        it 'calls get_gi_bill_status on the service' do
          instance.after_submit(user)
          expect(service).to have_received(:get_gi_bill_status)
          expect(BenefitsEducation::Service).to have_received(:new).with(user.icn).exactly(1).times
        end

        it 'sets the gi_bill_status instance variable' do
          # Load the VCR cassette response
          cassette_data =
            YAML.load_file('spec/support/vcr_cassettes/lighthouse/benefits_education/200_response_gt_6_mos.yml')

          # There are 2 interactions and the second one is the one we want
          response_body_string = cassette_data['http_interactions'][1]['response']['body']['string']
          response_status = cassette_data['http_interactions'][1]['response']['status']['code']

          # Parse the response JSON string to a hash
          parsed_body = JSON.parse(response_body_string)

          # Create a mock response object that matches what the service expects
          mock_raw_response = double('raw_response', status: response_status, body: parsed_body)
          mock_benefits_response = BenefitsEducation::Response.new(response_status, mock_raw_response)

          # Override the service mock for this specific test
          allow(service).to receive(:get_gi_bill_status).and_return(mock_benefits_response)

          instance.after_submit(user)
          expect(instance.instance_variable_get(:@gi_bill_status)).not_to be_nil
        end

        context 'when get_gi_bill_status raises an error' do
          before do
            allow(Rails.logger).to receive(:error)
            allow(service).to receive(:get_gi_bill_status).and_raise(StandardError)
          end

          it 'logs an error' do
            instance.after_submit(user)
            expect(Rails.logger).to have_received(:error)
          end
        end

        context 'stem automated decision processing' do
          it 'creates education_stem_automated_decision for user' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision).not_to be_nil
            expect(instance.education_benefits_claim.education_stem_automated_decision.user_uuid)
              .to eq(user.uuid)
            expect(instance.education_benefits_claim.education_stem_automated_decision.user_account_id)
              .to eq(user.user_account.id)
            expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
          end

          it 'saves user auth_headers' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
          end

          it 'always sets POA to nil' do
            instance.after_submit(user)
            expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
          end
        end

        context 'sending the confirmation email' do
          context 'when the form21_10203_confirmation_email feature flag is disabled' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(false)
              expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
            end

            it 'does not call SendSchoolCertifyingOfficialsEmail' do
              expect { instance.after_submit(user) }
                .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            end
          end

          context 'when the form21_10203_confirmation_email feature flag is enabled' do
            before { allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true) }

            context 'when there is no form email' do
              it 'does not send a confirmation email' do
                allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                allow(VANotify::EmailJob).to receive(:perform_async)

                subject = instance
                form = JSON.parse(subject.form)
                form.delete('email')
                subject.form = form.to_json
                subject.after_submit(user)

                expect(VANotify::EmailJob).not_to have_received(:perform_async)
              end
            end

            context 'when there is a form email' do
              context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is disabled' do
                before do
                  allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                      .and_return(false)
                end

                it 'sends the confirmation email without the callback parameters' do
                  allow(VANotify::EmailJob).to receive(:perform_async)

                  instance.after_submit(user)

                  expect(VANotify::EmailJob).to have_received(:perform_async).with(
                    'test@sample.com',
                    'form21_10203_confirmation_email_template_id',
                    {
                      'first_name' => 'MARK',
                      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                      'confirmation_number' => instance.education_benefits_claim.confirmation_number,
                      'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                    }
                  )
                  allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                end
              end

              context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is enabled' do
                let(:callback_options) do
                  {
                    callback_metadata: {
                      notification_type: 'confirmation',
                      form_number: '22-10203',
                      statsd_tags: {
                        service: 'submit-10203-form', function: 'form_10203_failure_confirmation_email_sending'
                      }
                    }
                  }
                end

                before do
                  allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                      .and_return(true)
                end

                it 'sends the confirmation email with the form email with the callback paarameters' do
                  allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
                  allow(VANotify::EmailJob).to receive(:perform_async)

                  subject = instance
                  subject.after_submit(user)

                  expect(VANotify::EmailJob).to have_received(:perform_async).with(
                    'test@sample.com',
                    'form21_10203_confirmation_email_template_id',
                    {
                      'first_name' => 'MARK',
                      'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                      'confirmation_number' => subject.education_benefits_claim.confirmation_number,
                      'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                    },
                    Settings.vanotify.services.va_gov.api_key,
                    callback_options
                  )
                end
              end
            end
          end
        end

        # we don't have to test the user because we're on the logged in path
        context 'sending the school certifying officials email' do
          context 'when the send_email? FeatureFlipper is false' do
            before { allow(FeatureFlipper).to receive(:send_email?).and_return(false) }

            it 'does not call SendSchoolCertifyingOfficialsEmail' do
              expect { instance.after_submit(user) }
                .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
            end
          end

          context 'when the send_email? FeatureFlipper is true' do
            before { allow(FeatureFlipper).to receive(:send_email?).and_return(true) }

            context 'unauthorized' do
              before do
                allow(FeatureFlipper).to receive(:send_email?).and_return(true)
                expect(user).to receive(:authorize).with(:lighthouse, :access?).and_return(false).at_least(:once)
                expect(user.authorize(:lighthouse, :access?)).to be(false)
                mail = double('mail')
                allow(mail).to receive(:deliver_now)
                allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
              end

              it 'does not call SendSchoolCertifyingOfficialsEmail' do
                expect { instance.after_submit(user) }
                  .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
              end
            end

            context 'authorized' do
              before do
                expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
                expect(user).to receive(:authorize).with(:lighthouse, :access?).and_return(true).at_least(:once)
                expect(user.authorize(:lighthouse, :access?)).to be(true)
                mail = double('mail')
                allow(mail).to receive(:deliver_now)
                allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
                allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(false)
              end

              it 'increments the SendSchoolCertifyingOfficialsEmail job queue (calls the job)' do
                expect { instance.after_submit(user) }
                  .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(1)
              end

              it 'calls SendSchoolCertifyingOfficialsEmail with correct arguments (gibill status is {})' do
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)

                instance.after_submit(user)

                expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                  .to have_received(:perform_async)
                  .with(instance.id, false, {})
              end

              it 'calls SendSchoolCertifyingOfficialsEmail (remaining entitlement < 6 months)' do
                # Load the VCR cassette response
                cassette_data =
                  YAML.load_file('spec/support/vcr_cassettes/lighthouse/benefits_education/200_response.yml')
                # There are 2 interactions and the second one is the one we want
                response_body_string = cassette_data['http_interactions'][1]['response']['body']['string']
                response_status = cassette_data['http_interactions'][1]['response']['status']['code']

                # Parse the response JSON string to a hash
                parsed_body = JSON.parse(response_body_string)

                # Create a mock response object that matches what the service expects
                mock_raw_response = double('raw_response', status: response_status, body: parsed_body)
                mock_benefits_response = BenefitsEducation::Response.new(response_status, mock_raw_response)

                # Override the service mock for this specific test
                allow(service).to receive(:get_gi_bill_status).and_return(mock_benefits_response)
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)

                instance.after_submit(user)

                expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                  .to have_received(:perform_async)
                  .with(instance.id, true, '11902614')
              end

              it 'calls SendSchoolCertifyingOfficialsEmail (remaining entitlement >= 6 months)' do
                # Load the VCR cassette response
                cassette_data =
                  YAML.load_file('spec/support/vcr_cassettes/lighthouse/benefits_education/200_response_gt_6_mos.yml')
                # There are 2 interactions and the second one is the one we want
                response_body_string = cassette_data['http_interactions'][1]['response']['body']['string']
                response_status = cassette_data['http_interactions'][1]['response']['status']['code']

                # Parse the response JSON string to a hash
                parsed_body = JSON.parse(response_body_string)

                # Create a mock response object that matches what the service expects
                mock_raw_response = double('raw_response', status: response_status, body: parsed_body)
                mock_benefits_response = BenefitsEducation::Response.new(response_status, mock_raw_response)

                # Override the service mock for this specific test
                allow(service).to receive(:get_gi_bill_status).and_return(mock_benefits_response)
                allow(EducationForm::SendSchoolCertifyingOfficialsEmail).to receive(:perform_async)

                instance.after_submit(user)

                expect(EducationForm::SendSchoolCertifyingOfficialsEmail)
                  .to have_received(:perform_async)
                  .with(instance.id, false, '11902614')
              end
            end
          end
        end
      end

      context 'Not logged in' do
        before do
          mail = double('mail')
          allow(mail).to receive(:deliver_now)
          allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
        end

        it 'does not set @gi_bill_status' do
          instance.after_submit(nil)
          expect(instance.instance_variable_get(:@gi_bill_status)).to be_nil
        end

        it 'does not create education_stem_automated_decision' do
          instance.after_submit(nil)
          expect(instance.education_benefits_claim.education_stem_automated_decision).to be_nil
        end

        it 'does not call SendSchoolCertifyingOfficialsEmail' do
          expect { instance.after_submit(nil) }
            .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
        end

        context 'when there is no form email' do
          it 'does not send a confirmation email' do
            allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = instance
            form = JSON.parse(subject.form)
            form.delete('email')
            subject.form = form.to_json
            subject.after_submit(nil)

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end

        context 'when there is a form email' do
          context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is disabled' do
            before do
              allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                  .and_return(false)
            end

            it 'sends the confirmation email without the callback parameters' do
              allow(VANotify::EmailJob).to receive(:perform_async)

              instance.after_submit(nil)

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'test@sample.com',
                'form21_10203_confirmation_email_template_id',
                {
                  'first_name' => 'MARK',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => instance.education_benefits_claim.confirmation_number,
                  'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                }
              )
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
            end
          end

          context 'when the form1995_confirmation_email_with_silent_failure_processing feature flag is enabled' do
            let(:callback_options) do
              {
                callback_metadata: {
                  notification_type: 'confirmation',
                  form_number: '22-10203',
                  statsd_tags: { service: 'submit-10203-form',
                                 function: 'form_10203_failure_confirmation_email_sending' }
                }
              }
            end

            before do
              allow(Flipper).to receive(:enabled?).with(:form1995_confirmation_email_with_silent_failure_processing)
                                                  .and_return(true)
            end

            it 'sends the confirmation email with the form email with the callback paarameters' do
              allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email).and_return(true)
              allow(VANotify::EmailJob).to receive(:perform_async)

              subject = instance
              subject.after_submit(nil)

              expect(VANotify::EmailJob).to have_received(:perform_async).with(
                'test@sample.com',
                'form21_10203_confirmation_email_template_id',
                {
                  'first_name' => 'MARK',
                  'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
                  'confirmation_number' => subject.education_benefits_claim.confirmation_number,
                  'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
                },
                Settings.vanotify.services.va_gov.api_key,
                callback_options
              )
            end
          end
        end
      end
    end
  end
end
