# frozen_string_literal: true

require 'rails_helper'

describe LighthousePolicy do
  subject { described_class }

  permissions :access? do
    context 'user has ICN and Participant ID' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :lighthouse)
      end
    end

    context 'user without ICN' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:icn).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end

    context 'user without Participant ID' do
      let(:user) { build(:user, :loa3) }

      before { allow(user).to receive(:participant_id).and_return(nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :lighthouse)
      end
    end
  end
end
