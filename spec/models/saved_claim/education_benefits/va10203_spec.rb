# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA10203 do
  let(:instance) { build(:va10203) }
  let(:user) { create(:evss_user) }

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-10203')

  describe '#in_progress_form_id' do
    it 'returns 22-10203' do
      expect(instance.in_progress_form_id).to eq('22-10203')
    end
  end

  describe '#after_submit' do
    context 'FeatureFlipper send email disabled' do
      before do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
      end

      it 'does not call SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(0)
      end
    end

    context 'Not logged in' do
      before do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
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
      end

      it 'calls SendSchoolCertifyingOfficialsEmail' do
        expect { instance.after_submit(user) }
          .to change(EducationForm::SendSchoolCertifyingOfficialsEmail.jobs, :size).by(1)
      end

      it 'calls StemApplicantConfirmationMailer' do
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        expect(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).once.and_return(mail)
        instance.after_submit(user)
      end
    end

    context 'unauthorized' do
      before do
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
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

      it 'calls StemApplicantConfirmationMailer' do
        mail = double('mail')
        allow(mail).to receive(:deliver_now)
        expect(StemApplicantConfirmationMailer).to receive(:build).with(instance, nil).once.and_return(mail)
        instance.after_submit(user)
      end
    end
  end
end
