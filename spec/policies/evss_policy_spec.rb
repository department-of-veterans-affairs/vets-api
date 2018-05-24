# frozen_string_literal: true

require 'rails_helper'

describe EVSSPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required evss attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :evss)
      end
    end

    context 'with a user who does not have the required evss attributes' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'denies access' do
        expect(subject).to_not permit(user, :evss)
      end
    end
  end
end
