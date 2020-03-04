# frozen_string_literal: true

require 'rails_helper'

describe PPIUPolicy do
  let(:user) { build(:evss_user) }

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
