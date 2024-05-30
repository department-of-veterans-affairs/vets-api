# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'
require 'feature_flipper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { build(:va10203, education_benefits_claim: create(:education_benefits_claim)) }
  let(:user) { create(:user) }
  let!(:user_verification) { create(:idme_user_verification, idme_uuid: user.idme_uuid) }

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

    context 'sends email confirmation via VANotify (with feature flag)' do
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
          'test@sample.com',
          'form21_10203_confirmation_email_template_id',
          {
            'first_name' => 'MARK',
            'date_submitted' => Time.zone.today.strftime('%B %d, %Y'),
            'confirmation_number' => confirmation_number,
            'regional_office_address' => "P.O. Box 4616\nBuffalo, NY 14240-4616"
          }
        )
      end
    end

    context 'FeatureFlipper send email disabled' do
      before do
        Flipper.disable(:form21_10203_confirmation_email)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(0)
        Flipper.enable(:form21_10203_confirmation_email)
      end
    end

    context 'stem_automated_decision feature disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email)
      end

      it 'creates education_stem_automated_decision for user' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(false).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision).not_to be_nil
        expect(instance.education_benefits_claim.education_stem_automated_decision.user_uuid)
          .to eq(user.uuid)
        expect(instance.education_benefits_claim.education_stem_automated_decision.user_account_id)
          .to eq(user.user_account.id)
        expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
      end

      it 'saves user auth_headers' do
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(false).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision.auth_headers).not_to be_nil
      end

      it 'populates claim with user POA' do
        expect(user).to receive(:power_of_attorney).and_return({ poa_code: 'aaa' })
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(false).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to eq(true)
      end

      it 'treats user POA nil as nil' do
        expect(user).to receive(:power_of_attorney).and_return(nil)
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(false).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
      end

      it 'handles POA exception' do
        expect(user).to receive(:power_of_attorney).and_raise(StandardError)
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(false).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
      end

      it 'does not create education_stem_automated_decision without user' do
        instance.after_submit(nil)
        expect(instance.education_benefits_claim.education_stem_automated_decision).to be_nil
      end
    end

    context 'stem_automated_decision feature enabled' do
      it 'does not load user POA' do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        allow(Flipper).to receive(:enabled?).with(:form21_10203_confirmation_email)
        expect(Flipper).to receive(:enabled?).with(:stem_automated_decision, user).and_return(true).at_least(:once)
        instance.after_submit(user)
        expect(instance.education_benefits_claim.education_stem_automated_decision.poa).to be_nil
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
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(0)
      end
    end

    context 'authorized' do
      before do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
        Flipper.disable(:form21_10203_confirmation_email)
      end

      after do
        Flipper.enable(:form21_10203_confirmation_email)
      end

      it 'calls SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(1)
      end
    end

    context 'unauthorized' do
      before do
        allow(FeatureFlipper).to receive(:send_email?).and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(false).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(false)
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        allow(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).and_return(mail)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(0)
      end
    end
  end
end
