# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Account creation and upgrade' do
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
           email: 'vets.gov.user+0@gmail.com',
           vha_facility_ids: vha_facility_ids)
  end

  let(:user_ssn) { mvi_profile.ssn }

  let(:mhv_ids) { [] }
  let(:vha_facility_ids) { ['450'] }

  let(:terms) { create(:terms_and_conditions, latest: true, name: MHVAccount::TERMS_AND_CONDITIONS_NAME) }

  before do
    stub_mpi(mvi_profile)
    sign_in_as(user)
  end

  shared_examples 'a failed POST #create' do |options|
    it "responds with #{options[:http_status]}" do
      post v0_mhv_account_path
      expect(response).to have_http_status(options[:http_status])
      expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
    end
  end

  shared_examples 'a failed POST #upgrade' do |options|
    it "responds with #{options[:http_status]}" do
      post '/v0/mhv_account/upgrade'
      expect(response).to have_http_status(options[:http_status])
      expect(JSON.parse(response.body)['errors'].first['detail']).to eq(options[:message])
    end
  end

  shared_examples 'a successful GET #show' do |options|
    it 'responds with JSON indicating current account state / level' do
      get v0_mhv_account_path
      expect(response).to be_successful
      base_response_body = JSON.parse(response.body)['data']['attributes']
      expect(base_response_body['account_state']).to eq(options[:account_state])
      expect(base_response_body['account_level']).to eq(options[:account_level])
    end
  end

  shared_context 'ssn mismatch' do |options|
    let(:user_ssn) { '999999999' }

    it_behaves_like 'a successful GET #show', account_state: 'needs_ssn_resolution',
                                              account_level: options&.dig(:account_level)
    it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                             message: V0::MHVAccountsController::CREATE_ERROR
    it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                              message: V0::MHVAccountsController::UPGRADE_ERROR
  end

  shared_context 'non va patient' do |options|
    let(:vha_facility_ids) { [] }

    it_behaves_like 'a successful GET #show', account_state: 'needs_va_patient',
                                              account_level: options&.dig(:account_level)
    it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                             message: V0::MHVAccountsController::CREATE_ERROR
    it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                              message: V0::MHVAccountsController::UPGRADE_ERROR
  end

  shared_examples 'a successful POST #create' do
    it 'creates' do
      VCR.use_cassette('mhv_account_creation/creates_an_account') do
        post v0_mhv_account_path
        expect(response).to have_http_status(:created)
        expect(JSON.parse(response.body)['data']['attributes']).to eq(
          'account_level' => 'Advanced',
          'account_state' => 'registered',
          'terms_and_conditions_accepted' => true
        )
      end
    end
  end

  shared_examples 'a successful POST #upgrade' do
    it 'upgrades' do
      VCR.use_cassette('mhv_account_creation/upgrades_an_account') do
        post '/v0/mhv_account/upgrade'
        expect(response).to have_http_status(:accepted)
        expect(JSON.parse(response.body)['data']['attributes']).to eq(
          'account_level' => 'Premium',
          'account_state' => 'upgraded',
          'terms_and_conditions_accepted' => true
        )
      end
    end
  end

  shared_examples 'an unsuccessful POST #create' do
    it 'fails to create' do
      VCR.use_cassette('mhv_account_creation/account_creation_unknown_error') do
        post v0_mhv_account_path
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('Something went wrong. Please try again later.')
      end
    end
  end

  shared_examples 'an unsuccessful POST #upgrade' do
    it 'fails to upgrade' do
      VCR.use_cassette('mhv_account_creation/account_creation_unknown_error') do
        post '/v0/mhv_account/upgrade'
        expect(response).to have_http_status(:bad_request)
        expect(JSON.parse(response.body)['errors'].first['detail'])
          .to eq('Something went wrong. Please try again later.')
      end
    end
  end

  context 'without T&C acceptance' do
    it_behaves_like 'a successful GET #show', account_state: 'needs_terms_acceptance', account_level: nil
    it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                             message: V0::MHVAccountsController::CREATE_ERROR
    it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                              message: V0::MHVAccountsController::UPGRADE_ERROR
    it_behaves_like 'ssn mismatch'
    it_behaves_like 'non va patient'
  end

  context 'with T&C acceptance' do
    before { create(:terms_and_conditions_acceptance, terms_and_conditions: terms, user_uuid: user.uuid) }

    it_behaves_like 'ssn mismatch'
    it_behaves_like 'non va patient'

    context 'without an account' do
      around do |example|
        VCR.use_cassette('mhv_account_type_service/advanced') do
          example.run
        end
      end

      it_behaves_like 'a successful GET #show', account_state: 'no_account', account_level: nil
      it_behaves_like 'a successful POST #create'
      it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                                message: V0::MHVAccountsController::UPGRADE_ERROR
    end

    context 'with account' do
      let(:mhv_ids) { ['14221465'] }

      context 'that is existing' do
        %w[Basic Advanced].each do |type|
          context type do
            around do |example|
              # by wrapping these cassettes, we're ensuring that after a successful upgrade, the serialized
              VCR.use_cassette('mhv_account_type_service/premium') do # account level is 'Premium'
                VCR.use_cassette("mhv_account_type_service/#{type.downcase}") do
                  example.run
                end
              end
            end

            it_behaves_like 'a successful GET #show', account_state: 'existing', account_level: type
            it_behaves_like 'ssn mismatch', account_level: type
            it_behaves_like 'non va patient', account_level: type
            it_behaves_like 'a successful POST #upgrade'
            it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                                     message: V0::MHVAccountsController::CREATE_ERROR
          end
        end

        %w[Premium Error Unknown].each do |type|
          context type do
            around do |example|
              VCR.use_cassette("mhv_account_type_service/#{type.downcase}") do
                example.run
              end
            end

            it_behaves_like 'a successful GET #show', account_state: 'existing', account_level: type
            it_behaves_like 'ssn mismatch', account_level: type
            it_behaves_like 'non va patient', account_level: type
            it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                                     message: V0::MHVAccountsController::CREATE_ERROR
            it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                                      message: V0::MHVAccountsController::UPGRADE_ERROR
          end
        end
      end

      context 'that is registered' do
        before do
          MHVAccount.create(user_uuid: user.uuid, mhv_correlation_id: mhv_ids.first,
                            account_state: 'registered', registered_at: Time.current)
        end

        around do |example|
          # by wrapping these cassettes, we're ensuring that after a successful upgrade, the serialized
          VCR.use_cassette('mhv_account_type_service/premium') do # account level is 'Premium'
            VCR.use_cassette('mhv_account_type_service/advanced') do
              example.run
            end
          end
        end

        it_behaves_like 'a successful GET #show', account_state: 'registered', account_level: 'Advanced'
        it_behaves_like 'ssn mismatch', account_level: 'Advanced'
        it_behaves_like 'non va patient', account_level: 'Advanced'
        it_behaves_like 'a successful POST #upgrade'
        it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                                 message: V0::MHVAccountsController::CREATE_ERROR
      end

      context 'that is upgraded' do
        before do
          MHVAccount.create(user_uuid: user.uuid, mhv_correlation_id: mhv_ids.first,
                            account_state: 'upgraded', upgraded_at: Time.current)
        end

        around do |example|
          VCR.use_cassette('mhv_account_type_service/premium') do
            example.run
          end
        end

        it_behaves_like 'a successful GET #show', account_state: 'upgraded', account_level: 'Premium'
        it_behaves_like 'ssn mismatch', account_level: 'Premium'
        it_behaves_like 'non va patient', account_level: 'Premium'
        it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                                 message: V0::MHVAccountsController::CREATE_ERROR
      end

      context 'that is upgraded has registered_at but does not have upgraded at' do
        before do
          MHVAccount.create(user_uuid: user.uuid, mhv_correlation_id: mhv_ids.first,
                            account_state: 'upgraded', registered_at: Time.current, upgraded_at: nil)
        end

        around do |example|
          VCR.use_cassette('mhv_account_type_service/premium') do
            example.run
          end
        end

        it_behaves_like 'a successful GET #show', account_state: 'upgraded', account_level: 'Premium'
        it_behaves_like 'ssn mismatch', account_level: 'Premium'
        it_behaves_like 'non va patient', account_level: 'Premium'
        it_behaves_like 'a failed POST #create', http_status: :forbidden,
                                                 message: V0::MHVAccountsController::CREATE_ERROR
        it_behaves_like 'a failed POST #upgrade', http_status: :forbidden,
                                                  message: V0::MHVAccountsController::UPGRADE_ERROR
      end
    end
  end
end
