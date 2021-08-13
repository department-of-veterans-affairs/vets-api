# frozen_string_literal: true

require 'rails_helper'

describe PPIUPolicy do
  let(:user) { build(:evss_user) }

  permissions :access? do
    before do
      expect(user).to receive(:multifactor).and_return(true)
    end

    context 'with a user with the feature enabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:direct_deposit_cnp, instance_of(User)).and_return(true)
      end

      it 'allows access' do
        expect(described_class).to permit(user, :ppiu)
      end
    end

    context 'with a user with the feature disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:direct_deposit_cnp, instance_of(User)).and_return(false)
      end

      it 'disallows access' do
        expect(described_class).not_to permit(user, :ppiu)
      end
    end
  end

  permissions :access_update? do
    context 'with a user who is competent, has no fiduciary, and is not deceased' do
      it 'allows access' do
        VCR.use_cassette('evss/ppiu/payment_information') do
          expect(described_class).to permit(user, :ppiu)
        end
      end
    end

    context 'with a user who is not competent or has fiduciary or is deceased' do
      it 'disallows access' do
        VCR.use_cassette('evss/ppiu/pay_info_unauthorized') do
          expect(described_class).not_to permit(user, :ppiu)
        end
      end
    end
  end
end
