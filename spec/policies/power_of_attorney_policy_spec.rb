# frozen_string_literal: true

require 'rails_helper'

describe PowerOfAttorneyPolicy do
  subject { described_class }

  permissions :access? do
    context 'when user is LOA3, has an ICN, and has a participant_id' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :power_of_attorney)
      end
    end

    context 'when user is LOA3 but does not have an ICN' do
      let(:user) { build(:user, :loa3, icn: nil) }

      it 'denies access due to missing ICN' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end

    context 'when user is LOA3 but does not have a participant_id' do
      let(:user) { build(:user, :loa3, participant_id: nil) }

      it 'denies access due to missing participant_id' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end

    context 'when user is not LOA3' do
      let(:user) { build(:user, :loa1) }

      it 'denies access due to not being LOA3' do
        expect(subject).not_to permit(user, :power_of_attorney)
      end
    end
  end
end
