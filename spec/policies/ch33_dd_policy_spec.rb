# frozen_string_literal: true

require 'rails_helper'

describe Ch33DdPolicy do
  let(:user) { FactoryBot.build(:ch33_dd_user) }

  permissions :access? do
    context 'with an idme user' do
      it 'allows access' do
        expect(described_class).to permit(user, :ch33_dd)
      end
    end

    context 'with a non idme user' do
      let(:user) { build(:user, :loa3, :mhv) }

      it 'disallows access' do
        expect(described_class).not_to permit(user, :ch33_dd)
      end
    end

    context 'with a user with the feature enabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:direct_deposit_edu, instance_of(User)).and_return(true)
      end

      it 'allows access' do
        expect(described_class).to permit(user, :ch33_dd)
      end
    end

    context 'with a user with the feature disabled' do
      before do
        expect(Flipper).to receive(:enabled?).with(:direct_deposit_edu, instance_of(User)).and_return(false)
      end

      it 'disallows access' do
        expect(described_class).not_to permit(user, :ch33_dd)
      end
    end
  end
end
