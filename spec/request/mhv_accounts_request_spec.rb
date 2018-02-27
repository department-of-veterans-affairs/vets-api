# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account creation and upgrade', type: :request do
  let(:mvi_profile) do
    build(:mvi_profile,
          icn: '1012667122V019349',
          given_names: %w[Hector],
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

  let(:terms) { create(:terms_and_conditions, latest: true, name: MhvAccount::TERMS_AND_CONDITIONS_NAME) }
  let(:tc_accepted) { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, created_at: Time.current) }

  before(:each) do
    stub_mvi(mvi_profile)
    use_authenticated_current_user(current_user: user)
  end

  context 'without accepted terms and conditions' do
    it 'responds to GET #show' do
      get v0_mhv_account_path
      expect(response).to be_success
      expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('needs_terms_acceptance')
    end

    it 'raises error for POST #create' do
      post v0_mhv_account_path
      expect(response).to have_http_status(:forbidden)
    end
  end

  context 'with accepted terms and conditions' do
    before { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

    context 'without an account' do
      it 'responds to GET #show' do
        get v0_mhv_account_path
        expect(response).to be_success
        expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('unknown')
      end

      it 'responds to POST #create' do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
            post v0_mhv_account_path
          end
        end
        expect(response).to have_http_status(:accepted)
        expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('upgraded')
      end

      it 'handles creation error in POST #create' do
        VCR.use_cassette('mhv_account_creation/account_creation_unknown_error') do
          post v0_mhv_account_path
        end
        expect(response).to have_http_status(:bad_request)
      end

      it 'handles upgrade error in POST #create' do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error') do
            post v0_mhv_account_path
          end
        end
        expect(response).to have_http_status(:bad_request)
      end
    end

    context 'with an account' do
      let(:mhv_ids) { ['14221465'] }

      context 'that is existing' do
        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('existing')
        end

        it 'raises error for POST #create' do
          post v0_mhv_account_path
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'that is registered' do
        before(:each) do
          mhv_account = MhvAccount.find_or_initialize_by(user_uuid: user.uuid)
          mhv_account.update(account_state: 'registered', registered_at: Time.current)
        end

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('registered')
        end

        it 'responds to POST #create' do
          VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
            post v0_mhv_account_path
          end
          expect(response).to have_http_status(:accepted)
          expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('upgraded')
        end

        it 'handles upgrade error in POST #create' do
          VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error') do
            post v0_mhv_account_path
          end
          expect(response).to have_http_status(:bad_request)
        end
      end

      context 'that is upgraded' do
        before(:each) do
          mhv_account = MhvAccount.find_or_initialize_by(user_uuid: user.uuid)
          mhv_account.update(account_state: 'upgraded', upgraded_at: Time.current)
        end

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('upgraded')
        end

        it 'raises error for POST #create' do
          post v0_mhv_account_path
          expect(response).to have_http_status(:forbidden)
        end
      end
    end
  end
end
