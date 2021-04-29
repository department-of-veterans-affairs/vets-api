# frozen_string_literal: true

require 'rails_helper'

describe DebtPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required debt attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :debt)
      end
    end

    context 'with a user who does not have the required debt attributes' do
      let(:user) { build(:user, :loa3) }

      it 'denies access' do
        user.identity.attributes = {
          icn: nil,
          ssn: nil
        }

        expect(subject).not_to permit(user, :debt)
      end
    end
  end
end
