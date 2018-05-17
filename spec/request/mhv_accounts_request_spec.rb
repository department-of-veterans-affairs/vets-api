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
           ssn: user_ssn,
           first_name: mvi_profile.given_names.first,
           last_name: mvi_profile.family_name,
           gender: mvi_profile.gender,
           birth_date: mvi_profile.birth_date,
           email: 'vets.gov.user+0@gmail.com')
  end

  let(:user_ssn) { mvi_profile.ssn }

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

    context 'with ssn mismatch' do
      let(:user_ssn) { '999999999' }

      it 'responds to GET #show' do
        get v0_mhv_account_path
        expect(response).to be_success
        expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('needs_ssn_resolution')
      end

      it 'raises error for POST #create' do
        post v0_mhv_account_path
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'with non va patient' do
      let(:vha_facility_ids) { [] }

      it 'responds to GET #show' do
        get v0_mhv_account_path
        expect(response).to be_success
        expect(JSON.parse(response.body)['data']['attributes']['account_state']).to eq('needs_va_patient')
      end

      it 'raises error for POST #create' do
        post v0_mhv_account_path
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  context 'with accepted terms and conditions' do
    before { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

    context 'without an account' do
      it 'responds to GET #show' do
        get v0_mhv_account_path
        expect(response).to be_success
        expect(JSON.parse(response.body)['data']['attributes'])
          .to eq('account_level' => nil, 'account_state' => 'no_account')
      end

      it 'responds to POST #create' do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          VCR.use_cassette('mhv_account_type_service/advanced') do
            VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
              post v0_mhv_account_path
            end
          end
        end
        expect(response).to have_http_status(:accepted)
        expect(JSON.parse(response.body)['data']['attributes'])
          .to eq('account_level' => 'Premium', 'account_state' => 'upgraded')
      end

      it 'handles creation error in POST #create' do
        VCR.use_cassette('mhv_account_creation/account_creation_unknown_error') do
          post v0_mhv_account_path
        end
        expect(response).to have_http_status(:bad_request)
      end

      it 'handles upgrade error in POST #create' do
        VCR.use_cassette('mhv_account_creation/creates_an_account') do
          VCR.use_cassette('mhv_account_type_service/advanced') do
            VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error') do
              post v0_mhv_account_path
            end
          end
        end
        expect(response).to have_http_status(:bad_request)
      end

      context 'with ssn mismatch' do
        let(:user_ssn) { '999999999' }

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('account_level' => nil, 'account_state' => 'needs_ssn_resolution')
        end

        it 'raises error for POST #create' do
          post v0_mhv_account_path
          expect(response).to have_http_status(:forbidden)
        end
      end

      context 'with non va patient' do
        let(:vha_facility_ids) { [] }

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('account_level' => nil, 'account_state' => 'needs_va_patient')
        end

        it 'raises error for POST #create' do
          post v0_mhv_account_path
          expect(response).to have_http_status(:forbidden)
        end
      end
    end

    context 'with account' do
      let(:mhv_ids) { ['14221465'] }

      context 'that is' do
        %w[Basic Advanced].each do |type|
          context type do
            around(:each) do |example|
              VCR.use_cassette("mhv_account_type_service/#{type.downcase}", allow_playback_repeats: true) do
                example.run
              end
            end

            it 'responds to GET #show' do
              get v0_mhv_account_path
              expect(response).to be_success
              expect(JSON.parse(response.body)['data']['attributes'])
                .to eq('account_level' => type, 'account_state' => 'existing')
            end

            it 'raises error for POST #create' do
              VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
                post v0_mhv_account_path
              end
              expect(JSON.parse(response.body)['data']['attributes'])
                .to eq('account_level' => 'Premium', 'account_state' => 'upgraded')
            end
          end
        end

        %w[Premium Error Unknown].each do |type|
          context type do
            around(:each) do |example|
              VCR.use_cassette("mhv_account_type_service/#{type.downcase}", allow_playback_repeats: true) do
                example.run
              end
            end

            it 'responds to GET #show' do
              get v0_mhv_account_path
              expect(response).to be_success
              expect(JSON.parse(response.body)['data']['attributes'])
                .to eq('account_level' => type, 'account_state' => 'existing')
            end

            it 'raises error for POST #create' do
              post v0_mhv_account_path
              expect(response).to have_http_status(:forbidden)
            end

            context 'with ssn mismatch' do
              let(:user_ssn) { '999999999' }

              it 'responds to GET #show' do
                get v0_mhv_account_path
                expect(response).to be_success
                expect(JSON.parse(response.body)['data']['attributes'])
                  .to eq('account_level' => type, 'account_state' => 'needs_ssn_resolution')
              end

              it 'raises error for POST #create' do
                post v0_mhv_account_path
                expect(response).to have_http_status(:forbidden)
              end
            end

            context 'with non va patient' do
              let(:vha_facility_ids) { [] }

              it 'responds to GET #show' do
                get v0_mhv_account_path
                expect(response).to be_success
                expect(JSON.parse(response.body)['data']['attributes'])
                  .to eq('account_level' => type, 'account_state' => 'needs_va_patient')
              end

              it 'raises error for POST #create' do
                post v0_mhv_account_path
                expect(response).to have_http_status(:forbidden)
              end
            end
          end
        end
      end

      context 'that is registered' do
        before(:each) do
          MhvAccount.create(user_uuid: user.uuid, mhv_correlation_id: mhv_ids.first,
                            account_state: 'registered', registered_at: Time.current)
        end

        around(:each) do |example|
          VCR.use_cassette('mhv_account_type_service/advanced', allow_playback_repeats: true) do
            example.run
          end
        end

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('account_level' => 'Advanced', 'account_state' => 'registered')
        end

        it 'responds to POST #create' do
          VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
            post v0_mhv_account_path
          end
          expect(response).to have_http_status(:accepted)
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('account_level' => 'Premium', 'account_state' => 'upgraded')
        end

        it 'handles upgrade error in POST #create' do
          VCR.use_cassette('mhv_account_creation/account_upgrade_unknown_error') do
            post v0_mhv_account_path
          end
          expect(response).to have_http_status(:bad_request)
        end

        context 'with ssn mismatch' do
          let(:user_ssn) { '999999999' }

          it 'responds to GET #show' do
            get v0_mhv_account_path
            expect(response).to be_success
            expect(JSON.parse(response.body)['data']['attributes'])
              .to eq('account_level' => 'Advanced', 'account_state' => 'needs_ssn_resolution')
          end

          it 'raises error for POST #create' do
            post v0_mhv_account_path
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'with non va patient' do
          let(:vha_facility_ids) { [] }

          it 'responds to GET #show' do
            get v0_mhv_account_path
            expect(response).to be_success
            expect(JSON.parse(response.body)['data']['attributes'])
              .to eq('account_level' => 'Advanced', 'account_state' => 'needs_va_patient')
          end

          it 'raises error for POST #create' do
            post v0_mhv_account_path
            expect(response).to have_http_status(:forbidden)
          end
        end
      end

      context 'that is upgraded' do
        before(:each) do
          MhvAccount.create(user_uuid: user.uuid, mhv_correlation_id: mhv_ids.first,
                            account_state: 'upgraded', upgraded_at: Time.current)
        end

        around(:each) do |example|
          VCR.use_cassette('mhv_account_type_service/premium') do
            example.run
          end
        end

        it 'responds to GET #show' do
          get v0_mhv_account_path
          expect(response).to be_success
          expect(JSON.parse(response.body)['data']['attributes'])
            .to eq('account_level' => 'Premium', 'account_state' => 'upgraded')
        end

        it 'raises error for POST #create' do
          post v0_mhv_account_path
          expect(response).to have_http_status(:forbidden)
        end

        context 'with ssn mismatch' do
          let(:user_ssn) { '999999999' }

          it 'responds to GET #show' do
            get v0_mhv_account_path
            expect(response).to be_success
            expect(JSON.parse(response.body)['data']['attributes'])
              .to eq('account_level' => 'Premium', 'account_state' => 'needs_ssn_resolution')
          end

          it 'raises error for POST #create' do
            post v0_mhv_account_path
            expect(response).to have_http_status(:forbidden)
          end
        end

        context 'with non va patient' do
          let(:vha_facility_ids) { [] }

          it 'responds to GET #show' do
            get v0_mhv_account_path
            expect(response).to be_success
            expect(JSON.parse(response.body)['data']['attributes'])
              .to eq('account_level' => 'Premium', 'account_state' => 'needs_va_patient')
          end

          it 'raises error for POST #create' do
            post v0_mhv_account_path
            expect(response).to have_http_status(:forbidden)
          end
        end
      end
    end
  end
end
