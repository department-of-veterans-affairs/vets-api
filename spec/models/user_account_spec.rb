# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAccount, type: :model do
  let(:user_account) { create(:user_account, icn:) }
  let(:icn) { nil }

  describe 'validations' do
    describe '#icn' do
      subject { user_account.icn }

      context 'when icn is nil' do
        let(:icn) { nil }

        it 'returns nil' do
          expect(subject).to be_nil
        end
      end

      context 'when icn is unique' do
        let(:icn) { 'kitty-icn' }

        it 'returns given icn value' do
          expect(subject).to eq(icn)
        end
      end

      context 'when icn is not unique' do
        let(:icn) { 'kitty-icn' }
        let(:expected_error_message) { 'Validation failed: Icn has already been taken' }

        before do
          create(:user_account, icn:)
        end

        it 'raises a validation error' do
          expect { subject }.to raise_error(ActiveRecord::RecordInvalid, expected_error_message)
        end
      end
    end
  end

  describe '#verified?' do
    subject { user_account.verified? }

    context 'when icn is not defined' do
      let(:icn) { nil }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'when icn is defined' do
      let(:icn) { 'some-icn-value' }

      it 'returns true' do
        expect(subject).to be true
      end
    end
  end

  describe '#needs_accepted_terms_of_use?' do
    subject { user_account.needs_accepted_terms_of_use? }

    context 'when icn is not defined' do
      let(:icn) { nil }

      it 'returns false' do
        expect(subject).to be false
      end
    end

    context 'when icn is defined' do
      let(:icn) { 'some-icn-value' }

      context 'and latest associated terms of use agreement does not exist' do
        let(:terms_of_use_agreement) { nil }

        it 'is true' do
          expect(subject).to be true
        end
      end

      context 'and latest associated terms of use agreement is declined' do
        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response: 'declined') }

        it 'is true' do
          expect(subject).to be true
        end
      end

      context 'and latest associated terms of use agreement is accepted' do
        let!(:terms_of_use_agreement) { create(:terms_of_use_agreement, user_account:, response: 'accepted') }

        it 'returns true' do
          expect(subject).to be false
        end
      end
    end
  end
end
