# frozen_string_literal: true

require 'rails_helper'

describe VAProfilePolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required VA Profile attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :va_profile)
      end
    end

    context 'with a user who does not have the required VA Profile attributes' do
      let(:user) { build(:user, :loa1) }

      it 'denies access' do
        expect(subject).not_to permit(user, :va_profile)
      end
    end
  end
end
