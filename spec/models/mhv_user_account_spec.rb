# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MHVUserAccount, type: :model do
  subject(:mhv_user_account) { described_class.new(attributes) }

  let(:attributes) do
    {
      user_profile_id:,
      premium:,
      champ_va:,
      patient:,
      sm_account_created:,
      message:
    }
  end

  let(:user_profile_id) { '123' }
  let(:premium) { true }
  let(:champ_va) { true }
  let(:patient) { false }
  let(:sm_account_created) { true }
  let(:message) { 'some-message' }

  context 'with valid attributes' do
    shared_examples 'a valid user account' do
      it 'is valid' do
        expect(mhv_user_account).to be_valid
      end
    end

    context 'when all attributes are present' do
      it 'is valid' do
        expect(mhv_user_account).to be_valid
      end
    end

    context 'when message is nil' do
      let(:message) { nil }

      it_behaves_like 'a valid user account'
    end
  end

  context 'with invalid attributes' do
    shared_examples 'an invalid user account' do
      it 'is invalid' do
        expect(mhv_user_account).not_to be_valid
      end
    end

    context 'when user_profile_id is nil' do
      let(:user_profile_id) { nil }

      it_behaves_like 'an invalid user account'
    end

    context 'when premium is nil' do
      let(:premium) { nil }

      it_behaves_like 'an invalid user account'
    end

    context 'when champ_va is nil' do
      let(:champ_va) { nil }

      it_behaves_like 'an invalid user account'
    end

    context 'when patient is nil' do
      let(:patient) { nil }

      it_behaves_like 'an invalid user account'
    end

    context 'when sm_account_created is nil' do
      let(:sm_account_created) { nil }

      it_behaves_like 'an invalid user account'
    end
  end
end
