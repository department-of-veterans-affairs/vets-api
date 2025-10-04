# frozen_string_literal: true

require 'rails_helper'

describe VyePolicy do
  subject { described_class }

  permissions :access? do
    context 'with a logged in user' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :vye)
      end
    end

    context 'without a logged in user' do
      let(:user) { nil }

      it 'denies access' do
        expect(subject).not_to permit(user, :vye)
      end
    end
  end
end
