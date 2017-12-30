# frozen_string_literal: true
require 'rails_helper'

RSpec.describe 'Account creation and upgrade', type: :request do
  let(:user) { build(:user, :loa3) }

  before(:each) do
    allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    use_authenticated_current_user(current_user: user)
  end

  context 'without an account' do
    let(:mhv_account) do
      double(
        'mhv_account',
        ineligible?: false,
        needs_terms_acceptance?: true,
        upgraded?: false,
        account_state: 'unknown'
      )
    end

    it 'responds to GET #show' do
      get v0_mhv_account_path
      expect(response).to be_success
      expect(JSON.parse(response.body)['account_state']).to eq('unknown')
    end
  end

  context 'with an existing account' do
    let(:mhv_account) do
      double(
        'mhv_account',
        ineligible?: false,
        needs_terms_acceptance?: false,
        upgraded?: false,
        account_state: 'existing'
      )
    end

    it 'responds to GET #show' do
      get v0_mhv_account_path
      expect(response).to be_success
      expect(JSON.parse(response.body)['account_state']).to eq('existing')
    end
  end

  context 'with a registered account' do
    let(:mhv_account) do
      double(
        'mhv_account',
        ineligible?: false,
        needs_terms_acceptance?: false,
        upgraded?: false,
        account_state: 'registered'
      )
    end

    it 'responds to GET #show' do
      get v0_mhv_account_path
      expect(response).to be_success
      expect(JSON.parse(response.body)['account_state']).to eq('registered')
    end
  end

  context 'with an upgraded account' do
    let(:mhv_account) do
      double(
        'mhv_account',
        ineligible?: false,
        needs_terms_acceptance?: false,
        upgraded?: false,
        account_state: 'upgraded'
      )
    end

    it 'responds to GET #show' do
      get v0_mhv_account_path
      expect(response).to be_success
      expect(JSON.parse(response.body)['account_state']).to eq('upgraded')
    end
  end
end
