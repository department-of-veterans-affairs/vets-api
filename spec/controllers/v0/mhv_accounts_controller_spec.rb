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
    stub_mvi(mvi_profile)
    create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid)
  end

  context 'when not accessible' do
    it 'creates and upgrades the account' do
      request.env['HTTP_AUTHORIZATION'] = auth_header
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
end

