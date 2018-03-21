# frozen_string_literal: true

require 'rails_helper'

describe EVSSPolicy do
  subject { described_class }
  let(:user) { build(:user, :loa3) }

  permissions :access_common_client? do
    context 'with a user that has access' do
      it 'should return true' do
        expect(user).to receive(:beta_enabled?).with(user.uuid, 'evss_common_client').and_return(true)

        expect(subject).to permit(user, :evss)
      end
    end

    context 'when a user doesnt have access' do
      it 'should return false' do
        expect(subject).to_not permit(user, :evss)
      end
    end
  end

  permissions :access? do
    context 'with a user who has the required evss attributes' do
      it 'grants access' do
        expect(subject).to permit(user, :evss)
      end
    end

    context 'with a user who does not have the required evss attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).to_not permit(user, :evss)
      end
    end
  end
end
