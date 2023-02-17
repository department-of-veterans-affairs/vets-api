# frozen_string_literal: true

require 'rails_helper'

describe CoePolicy do
  subject { described_class }

  permissions :access? do
    context 'user is loa3 and has EDIPI' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :coe)
      end
    end

    context 'user is not loa3' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).not_to permit(user, :coe)
      end
    end

    context 'user does not have EDIPI' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:edipi).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :coe)
      end
    end
  end
end
