# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVUserAccount, type: :model do
  subject(:mhv_user_account) { described_class.new(attributes) }

  let(:attributes) do
    {
      user_profile_id:,
      champ_va:,
      patient:,
      sm_account:
    }
  end

  let(:user_profile_id) { '123' }
  let(:champ_va) { true }
  let(:patient) { false }
  let(:sm_account) { true }

  context 'with valid attributes' do
    it 'is valid' do
      expect(mhv_user_account).to be_valid
    end
  end

  context 'with invalid attributes' do
    shared_examples 'is invalid' do
      it 'is invalid' do
        expect(mhv_user_account).not_to be_valid
      end
    end

    context 'when user_profile_id is nil' do
      let(:user_profile_id) { nil }

      it_behaves_like 'is invalid'
    end

    context 'when champ_va is nil' do
      let(:champ_va) { nil }

      it_behaves_like 'is invalid'
    end

    context 'when patient is nil' do
      let(:patient) { nil }

      it_behaves_like 'is invalid'
    end

    context 'when sm_account is nil' do
      let(:sm_account) { nil }

      it_behaves_like 'is invalid'
    end
  end
end
