# frozen_string_literal: true

require 'rails_helper'
require Vye::Engine.root / 'spec/rails_helper'

RSpec.describe Vye::UserInfoPolicy do
  subject { described_class.new(user, user_info) }

  let(:user) { build(:user, :loa3) }
  let(:user_profile) { build(:vye_user_profile, icn: user.icn) }
  let(:user_info) { build(:vye_user_info, user_profile:) }

  describe '#show?' do
    context 'when user_info belongs to the current user' do
      it 'returns true' do
        expect(subject.show?).to be true
      end
    end

    context 'when user_info does not belong to the current user' do
      let(:other_user_profile) { build(:vye_user_profile, icn: 'different-icn') }
      let(:user_info) { build(:vye_user_info, user_profile: other_user_profile) }

      it 'returns false' do
        expect(subject.show?).to be false
      end
    end

    context 'when user is nil' do
      subject { described_class.new(nil, user_info) }

      it 'returns false' do
        expect(subject.show?).to be false
      end
    end

    context 'when user_info is nil' do
      let(:user_info) { nil }

      it 'returns false' do
        expect(subject.show?).to be false
      end
    end

    context 'when user has no icn' do
      let(:user) { build(:user, :loa3) }

      before do
        allow(user).to receive(:icn).and_return(nil)
      end

      it 'returns false' do
        expect(subject.show?).to be false
      end
    end

    context 'when user_info has no user_profile' do
      let(:user_info) { build(:vye_user_info, user_profile: nil) }

      it 'returns false' do
        expect(subject.show?).to be false
      end
    end
  end

  describe '#create?' do
    it 'is aliased to show?' do
      expect(subject.create?).to eq(subject.show?)
    end
  end
end
