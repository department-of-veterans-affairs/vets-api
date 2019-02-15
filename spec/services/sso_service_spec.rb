# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SSOService do
  include SAML::ResponseBuilder

  let(:saml_response) do
    build_saml_response(
      authn_context: authn_context,
      account_type: account_type,
      level_of_assurance: [highest_attained_loa],
      multifactor: [false]
    )
  end
  subject(:sso_service) { described_class.new(saml_response) }

  describe 'MHV Identity' do
    let(:authn_context) { 'myhealthevet' }
    let(:highest_attained_loa) { '1' }

    context 'Basic' do
      let(:account_type) { 'Basic' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Basic')
      end

      context 'with highest ID.me LOA 3' do
        let(:highest_attained_loa) { '3' }

        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet', account_type: 'Basic')
        end
      end
    end

    context 'Advanced' do
      let(:account_type) { 'Advanced' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Advanced')
      end

      context 'with ID.me LOA3' do
        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet', account_type: 'Advanced')
        end
      end
    end

    context 'myhealthevet_loa3' do
      let(:authn_context) { 'myhealthevet_loa3' }
      let(:highest_attained_loa) { '3' }

      %w[Basic Advanced].each do |account_type|
        context "with initial account type of #{account_type}" do
          let(:account_type) { account_type }

          it 'has a #new_user_identity which responds to #sign_in' do
            expect(sso_service.new_user_identity.sign_in)
              .to eq(service_name: 'myhealthevet', account_type: account_type)
          end
        end
      end
    end

    context 'myhealthevet_multifactor' do
      let(:authn_context) { 'myhealthevet_multifactor' }
      let(:highest_attained_loa) { '1' }

      %w[Basic Advanced Premium].each do |account_type|
        context "with initial account type of #{account_type}" do
          let(:account_type) { account_type }

          it 'has a #new_user_identity which responds to #sign_in' do
            expect(sso_service.new_user_identity.sign_in)
              .to eq(service_name: 'myhealthevet', account_type: account_type)
          end
        end
      end
    end

    context 'Premium' do
      let(:account_type) { 'Premium' }
      let(:highest_attained_loa) { '3' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Premium')
      end
    end
  end

  describe 'DS Logon Identity' do
    let(:authn_context) { 'dslogon' }
    let(:highest_attained_loa) { '1' }

    context 'dslogon assurance 1' do
      let(:account_type) { '1' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '1')
      end

      context 'with ID.me LOA3' do
        let(:highest_attained_loa) { '3' }

        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'dslogon', account_type: '1')
        end
      end
    end

    context 'dslogon_loa3' do
      let(:authn_context) { 'dslogon_loa3' }
      let(:highest_attained_loa) { '3' }

      %w[1 2].each do |account_type|
        context "with initial account type of #{account_type}" do
          let(:account_type) { account_type }

          it 'has a #new_user_identity which responds to #sign_in' do
            expect(sso_service.new_user_identity.sign_in)
              .to eq(service_name: 'dslogon', account_type: account_type)
          end
        end
      end
    end

    context 'dslogon_multifactor' do
      let(:authn_context) { 'dslogon_multifactor' }
      let(:highest_attained_loa) { '1' }

      %w[1 2].each do |account_type|
        context "with initial account type of #{account_type}" do
          let(:account_type) { account_type }

          it 'has a #new_user_identity which responds to #sign_in' do
            expect(sso_service.new_user_identity.sign_in)
              .to eq(service_name: 'dslogon', account_type: account_type)
          end
        end
      end
    end

    context 'dslogon assurance 2' do
      let(:account_type) { '2' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '2')
      end
    end

    context 'dslogon assurance 3' do
      let(:account_type) { '3' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '3')
      end
    end
  end

  describe 'IDme Identity' do
    let(:account_type) { 'N/A' }
    let(:highest_attained_loa) { '1' }

    context 'idme assurance 1' do
      let(:authn_context) { LOA::IDME_LOA1 }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme', account_type: 'N/A')
      end
    end

    context 'idme assurance 3' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:highest_attained_loa) { '3' }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme', account_type: 'N/A')
      end
    end
  end

  context 'invalid saml response' do
    let(:saml_response) { SAML::Response.new('') }

    it 'has Blank response error' do
      expect(sso_service.valid?).to be_falsey
      expect(sso_service.errors.full_messages).to eq(['Blank response'])
    end

    it '#persist_authentication! handles saml response errors' do
      expect(SAML::AuthFailHandler).to receive(:new).with(sso_service.saml_response).and_call_original
      sso_service.persist_authentication!
    end
  end
end
