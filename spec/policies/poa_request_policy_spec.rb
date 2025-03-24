# frozen_string_literal: true

require 'rails_helper'
describe POARequestPolicy do
  subject { described_class }

  permissions :access? do
    context 'when user has an ICN and is LOA3' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :power_of_attorney)
      end
    end

    context 'when user does not have an ICN nor LOA3' do
      let(:user) { build(:user, :loa1) }

      before do
        user.identity.attributes = {
          icn: nil
        }
      end

      it 'denies access' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end

  end
end
