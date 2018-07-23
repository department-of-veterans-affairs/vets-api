# frozen_string_literal: true

require 'rails_helper'

describe EMISPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required emis attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :emis)
      end
    end

    context 'with a user who does not have the required emis attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).to_not permit(user, :emis)
      end
    end
  end
end
