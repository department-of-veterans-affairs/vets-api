# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'
require 'feature_flipper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { build(:va10203, education_benefits_claim: create(:education_benefits_claim)) }
  let(:user) { create(:user) }

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
    let(:service) { instance_double(BenefitsEducation::Service) }

    before do
      allow(BenefitsEducation::Service).to receive(:new).and_return(service)
      allow(service).to receive(:get_gi_bill_status).and_return({})
    end

    it 'calls get_gi_bill_status on the service' do
      instance.after_submit(user)
      expect(service).to have_received(:get_gi_bill_status)
      # service created once to get gi bill status,
      # once to calculate remaining entitlement (for debugging in non-production environment)
      expect(BenefitsEducation::Service).to have_received(:new).with(user.icn).exactly(2).times
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

    context 'sends email confirmation via VANotify (with feature flag)' do
      let(:callback_options) do
        {
          callback_metadata: {
            notification_type: 'confirmation',
            form_number: '22-10203',
            statsd_tags: { service: 'submit-10203-form', function: 'form_10203_failure_confirmation_email_sending' }
          }
        }
      end

      it 'is skipped when feature flag is turned off' do
        Flipper.disable(:form21_10203_confirmation_email)
        allow(VANotify::EmailJob).to receive(:perform_async)

        instance.after_submit(user)

        expect(VANotify::EmailJob).not_to have_received(:perform_async)
        Flipper.enable(:form21_10203_confirmation_email)
      end

      it 'sends with form data' do
        Flipper.enable(:form21_10203_confirmation_email)
        allow(VANotify::EmailJob).to receive(:perform_async)

        subject = instance
        subject.after_submit(user)
        confirmation_number = subject.education_benefits_claim.confirmation_number

        expect(VANotify::EmailJob).to have_received(:perform_async).with(
          'abraham.lincoln@vets.gov',
          'form21_10203_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          },
          Settings.vanotify.services.va_gov.api_key,
          callback_options
        )
      end

      context 'when the user is not logged in' do
        let(:user) { nil }

        it 'sends the confirmation email using the email from the form' do
          Flipper.enable(:form21_10203_confirmation_email)
          allow(VANotify::EmailJob).to receive(:perform_async)

          subject = instance
          subject.after_submit(user)
          confirmation_number = subject.education_benefits_claim.confirmation_number

          expect(VANotify::EmailJob).to have_received(:perform_async).with(
            'test@sample.com',
            'form21_10203_confirmation_email_template_id',
            {
              'first_name' => 'MARK',
              'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
              'confirmation_number' => confirmation_number,
              'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
            },
            Settings.vanotify.services.va_gov.api_key,
            callback_options
          )
        end

        context 'when the email is not present (not logged in and no form email)' do
          it 'does not send the confirmation email' do
            Flipper.enable(:form21_10203_confirmation_email)
            allow(VANotify::EmailJob).to receive(:perform_async)

            subject = instance
            # remove the email from the form and put it back into the model
            # user is already nil so no email there either
            form = JSON.parse(subject.form)
            form.delete('email')
            subject.form = form.to_json
            subject.after_submit(user)

            expect(VANotify::EmailJob).not_to have_received(:perform_async)
          end
        end
      end
    end

    context 'FeatureFlipper send email disabled' do
      before do
        Flipper.disable(:form21_10203_confirmation_email)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
        Flipper.enable(:form21_10203_confirmation_email)
      end
    end

    context 'creates stem automated decision' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email)
      end

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

      it 'does not create education_stem_automated_decision without user' do
        instance.after_submit(nil)
        expect(instance.education_benefits_claim.education_stem_automated_decision).to be_nil
      end
    end

    context 'Not logged in' do
      before do
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(nil) }
          .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
      end
    end

    context 'authorized' do
      before do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to be(true)
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
        Flipper.disable(:form21_10203_confirmation_email)
      end

      after do
        Flipper.enable(:form21_10203_confirmation_email)
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
        cassette_data = YAML.load_file('spec/support/vcr_cassettes/lighthouse/benefits_education/200_response.yml')
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
        cassette_data = YAML.load_file('spec/support/vcr_cassettes/lighthouse/benefits_education/200_response_gt_6_mos.yml')
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

      context 'when the environment is production' do
        before { allow(Settings).to receive(:vsp_environment).and_return('production') }


      end
    end

    context 'unauthorized' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(false).at_least(:once)
        expect(user.authorize(:evss, :access?)).to be(false)
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .not_to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size)
      end
    end
  end
end
