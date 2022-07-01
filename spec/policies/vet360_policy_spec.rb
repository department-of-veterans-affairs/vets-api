# frozen_string_literal: true

require 'rails_helper'

describe Vet360Policy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required vet360 attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :vet360)
      end
    end

    context 'with a user who does not have the required vet360 attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).not_to permit(user, :vet360)
      end
    end
  end

  permissions :military_access? do
    context 'with a user who has the required vet360 attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :vet360)
      end
    end

    context 'with a user who does not have the required vet360 attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).not_to permit(user, :vet360)
      end
    end
  end
end
