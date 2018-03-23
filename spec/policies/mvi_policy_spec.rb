# frozen_string_literal: true

require 'rails_helper'

describe MVIPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required mvi attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :mvi)
      end
    end

    context 'with a user who does not have the required mvi attributes' do
      let(:user) { build(:user, :loa1, ssn: nil) }

      it 'denies access' do
        expect(subject).to_not permit(user, :mvi)
      end
    end
  end
end
