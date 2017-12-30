# frozen_string_literal: true
require 'rails_helper'

RSpec.describe V0::MHVAccountsController, type: :controller do
  let(:token) { 'abracadabra-open-sesame' }
  let(:auth_header) { ActionController::HttpAuthentication::Token.encode_credentials(token) }

  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w(Hector),
          family_name: 'Allen',
          suffix: nil,
          gender: 'M',
          birth_date: '1932-02-05',
          ssn: '796126859',
          mhv_ids: mhv_ids,
          vha_facility_ids: vha_facility_ids,
          home_phone: nil,
          address: mvi_profile_address)
  end

  let(:mvi_profile_address) do
    build(:mvi_profile_address,
          street: '20140624',
          city: 'Houston',
          state: 'TX',
          country: 'USA',
          postal_code: '77040')
  end

  let(:user) do
    create(:user, :loa3,
           ssn: mvi_profile.ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:mhv_ids) { [] }
  let(:vha_facility_ids) { ['450'] }

  let(:terms) { create(:terms_and_conditions, latest: true, name: 'mhvac') }

  before(:each) do
    Session.create(uuid: user.uuid, token: token)
    request.env['HTTP_AUTHORIZATION'] = auth_header
    stub_mvi(mvi_profile)
    create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid)
  end

  context 'without an account' do
    it 'shows an unknown state' do
      get :show
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['account_state']).to eq('unknown')
    end

    it 'creates and upgrades the account' do
      VCR.use_cassette('mhv_account_creation/creates_an_account') do
        VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
          post :create
          expect(response).to have_http_status(:created)
          expect(user.mhv_account.account_state).to eq('upgraded')
          expect(user.mhv_account.registered_at).to be_a(Time)
          expect(user.mhv_account.upgraded_at).to be_a(Time)
          expect(user.mhv_correlation_id).to eq('14221465')
        end
      end
    end
  end

  context 'with an existing account' do
    let(:mhv_ids) { ['14221465'] }

    it 'shows an existing state' do
      get :show
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['account_state']).to eq('existing')
    end

    it 'fails to create and upgrade the account' do
      expect(user.mhv_account.account_state).to eq('existing')
      expect(user.mhv_account.accessible?).to be_truthy
      post :create
      expect(response).to_not be_success
    end
  end

  context 'with a registered account' do
    let(:mhv_ids) { ['14221465'] }
    before do
      MhvAccount.create(user_uuid: user.uuid, registered_at: Time.current)
    end

    it 'shows a registered state' do
      get :show
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['account_state']).to eq('registered')
    end

    it 'upgrades the account' do
      VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
        post :create
        expect(user.mhv_account.account_state).to eq('upgraded')
        expect(response).to have_http_status(:created)
      end
    end
  end

  context 'with an upgraded account' do
    before do
      mhv_account = double('mhv_account', ineligible?: false, needs_terms_acceptance?: false, account_state: 'upgraded')
      allow(MhvAccount).to receive(:find_or_initialize_by).and_return(mhv_account)
    end

    it 'shows an upgraded state' do
      get :show
      expect(response).to be_success
      json = JSON.parse(response.body)
      expect(json['account_state']).to eq('upgraded')
    end

    it 'fails to create and upgrade the account' do
      post :create
      expect(response).to_not be_success
    end
  end
end
