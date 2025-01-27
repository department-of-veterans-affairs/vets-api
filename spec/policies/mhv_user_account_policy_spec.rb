# frozen_string_literal: true

require 'rails_helper'

describe MHVUserAccountPolicy do
  subject { described_class }

  permissions :show? do
    context 'with a user who can create an MHV account' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :mhv_user_account)
      end
    end

    context 'with a user who cannot create an MHV account' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).not_to permit(user, :mhv_user_account)
      end
    end
  end
end
