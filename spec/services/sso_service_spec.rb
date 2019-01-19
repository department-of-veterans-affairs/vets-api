# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SSOService do
  include SAML::ResponseBuilder

  subject(:sso_service) { described_class.new(saml_response) }

  describe 'MHV Identity' do
    context 'Basic' do
      let(:saml_response) { build_saml_response(authn_context: 'myhealthevet', account_type: 'Basic') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Basic', id_proof_type: 'not-verified')
      end

      context 'with ID.me LOA3' do
        let(:saml_response) do
          build_saml_response(authn_context: 'myhealthevet', account_type: 'Basic', level_of_assurance: ['3'])
        end

        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet', account_type: 'Basic', id_proof_type: 'not-verified')
        end
      end
    end

    context 'Advanced' do
      let(:saml_response) { build_saml_response(authn_context: 'myhealthevet', account_type: 'Advanced') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Advanced', id_proof_type: 'not-verified')
      end

      context 'with ID.me LOA3' do
        let(:saml_response) do
          build_saml_response(authn_context: 'myhealthevet', account_type: 'Advanced', level_of_assurance: ['3'])
        end

        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet', account_type: 'Advanced', id_proof_type: 'not-verified')
        end
      end
    end

    context 'myhealthevet_loa3' do
      %w[Basic Advanced].each do |account_type|
        context "with initial account type of #{account_type}" do
          let(:authn_context) { 'myhealthevet_loa3' }
          let(:saml_response) do
            build_saml_response(authn_context: authn_context, account_type: account_type, level_of_assurance: ['3'])
          end

          it 'has a #new_user_identity which responds to #sign_in' do
            expect(sso_service.new_user_identity.sign_in)
              .to eq(service_name: 'myhealthevet', account_type: account_type, id_proof_type: 'idme')
          end
        end
      end
    end

    context 'Premium' do
      let(:saml_response) { build_saml_response(authn_context: 'myhealthevet', account_type: 'Premium') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet', account_type: 'Premium', id_proof_type: 'myhealthevet')
      end
    end
  end

  describe 'DS Logon Identity' do
    context 'dslogon assurance 1' do
      let(:saml_response) { build_saml_response(authn_context: 'dslogon', account_type: '1') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '1', id_proof_type: 'not-verified')
      end

      context 'with ID.me LOA3' do
        let(:saml_response) do
          build_saml_response(authn_context: 'dslogon', account_type: '1', level_of_assurance: ['3'])
        end

        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'dslogon', account_type: '1', id_proof_type: 'not-verified')
        end
      end
    end

    context 'dslogon assurance 2' do
      let(:saml_response) { build_saml_response(authn_context: 'dslogon', account_type: '2') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '2', id_proof_type: 'dslogon')
      end
    end

    context 'dslogon assurance 3' do
      let(:saml_response) { build_saml_response(authn_context: 'dslogon', account_type: '3') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon', account_type: '3', id_proof_type: 'dslogon')
      end
    end
  end

  describe 'IDme Identity' do
    context 'idme assurance 1' do
      let(:saml_response) do
        build_saml_response(authn_context: SAML::ResponseBuilder::IDMELOA1, level_of_assurance: ['3'])
      end

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme', account_type: 'N/A', id_proof_type: 'not-verified')
      end
    end

    context 'idme assurance 3' do
      let(:saml_response) { build_saml_response(authn_context: SAML::ResponseBuilder::IDMELOA3) }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme', account_type: 'N/A', id_proof_type: 'idme')
      end
    end
  end

  context 'invalid saml response' do
    let(:saml_response) { OneLogin::RubySaml::Response.new('') }

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
