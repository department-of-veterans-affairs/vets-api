# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VANotify::Veteran, type: :model do
  let(:user_account) { create(:user_account, icn: icn) }
  let(:icn) { nil }
  let(:in_progress_form) { create(:in_progress_686c_form, user_account: user_account) }
  let(:subject) { VANotify::Veteran.new(in_progress_form) }

  describe '#first_name' do
    context '686c' do
      it 'returns the first_name from form data' do
        expect(subject.first_name).to eq('first_name')
      end
    end

    context '1010ez' do
      let(:in_progress_form) { create(:in_progress_1010ez_form, user_account: user_account) }

      it 'returns the first_name from form data' do
        expect(subject.first_name).to eq('first_name')
      end
    end
  end

  describe '#icn' do
    context 'with icn' do
      let(:icn) { 'icn' }

      it 'returns the icn associated to the user account associated to the in_progress_form if it exists' do
        expect(subject.icn).to eq('icn')
      end
    end

    context 'without associated account' do
      let(:user_account) { nil }

      it 'returns nil if no matching account is found' do
        expect(subject.icn).to eq(nil)
      end
    end

    context 'without icn' do
      let(:icn) { nil }

      it 'returns nil if no icn is found' do
        expect(subject.icn).to eq(nil)
      end
    end
  end
end
