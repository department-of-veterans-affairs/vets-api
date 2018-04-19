# frozen_string_literal: true

require 'rails_helper'

describe AppealsPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required appeals attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :appeals)
      end
    end

    context 'with a user who does not have the required appeals attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).to_not permit(user, :appeals)
      end
    end
  end
end
