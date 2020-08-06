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
    context 'feature flag edu_benefits_stem_scholarship disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:edu_benefits_stem_scholarship).and_return(false)
      end

      it 'does not call SendSCOEmail' do
        expect { instance.after_submit(user) }.to change(EducationForm::SendSCOEmail.jobs, :size).by(0)
      end
    end

    context 'FeatureFlipper send email disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:edu_benefits_stem_scholarship).and_return(true)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
      end

      it 'does not call SendSCOEmail' do
        expect { instance.after_submit(user) }.to change(EducationForm::SendSCOEmail.jobs, :size).by(0)
      end
    end

    context 'Not logged in' do
      before do
        expect(Flipper).to receive(:enabled?).with(:edu_benefits_stem_scholarship).and_return(true)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(false)
      end

      it 'does not call SendSCOEmail' do
        expect { instance.after_submit(nil) }.to change(EducationForm::SendSCOEmail.jobs, :size).by(0)
      end
    end

    context 'authorized' do
      before do
        expect(Flipper).to receive(:enabled?).with(:edu_benefits_stem_scholarship).and_return(true)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(true).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(true)
      end

      it 'calls SendSCOEmail' do
        expect { instance.after_submit(user) }.to change(EducationForm::SendSCOEmail.jobs, :size).by(1)
      end
    end

    context 'unauthorized' do
      before do
        expect(Flipper).to receive(:enabled?).with(:edu_benefits_stem_scholarship).and_return(true)
        expect(FeatureFlipper).to receive(:send_email?).once.and_return(true)
        expect(user).to receive(:authorize).with(:evss, :access?).and_return(false).at_least(:once)
        expect(user.authorize(:evss, :access?)).to eq(false)
      end

      it 'does not call SendSCOEmail' do
        unauthorized_evss_user = build(:unauthorized_evss_user, :loa3)
        expect { instance.after_submit(unauthorized_evss_user) }
          .to change(EducationForm::SendSCOEmail.jobs, :size).by(0)
      end
    end
  end
end
