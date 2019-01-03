# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SSOService do
  subject(:sso_service) { described_class.new(saml_response) }

  before(:each) do
    sso_service.persist_authentication!
  end

  describe 'MHV Identity' do
    context 'Basic' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('myhealthevet', 'Basic') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet')
      end

      context 'with ID.me LOA3' do
        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet')
          saml_response_verifying_identity = SAML::ResponseBuilder.saml_response('loa3')
          sso_service_verifying_identity = described_class.new(saml_response_verifying_identity)
          expect(sso_service_verifying_identity.new_user_identity.sign_in)
            .to eq(service_name: 'idme')
          sso_service_verifying_identity.persist_authentication!
          expect(sso_service_verifying_identity.new_user_identity.sign_in)
            .to eq(service_name: 'myhealthevet')
        end
      end
    end

    context 'Advanced' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('myhealthevet', 'Advanced') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet')
      end
    end

    context 'myhealthevet_loa3' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('myhealthevet_loa3', 'Advanced') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet')
      end
    end

    context 'Premium' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('myhealthevet', 'Premium') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'myhealthevet')
      end
    end
  end

  describe 'DS Logon Identity' do
    context 'dslogon assurance 1' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('dslogon', '1') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon')
      end

      context 'with ID.me LOA3' do
        it 'has a #new_user_identity which responds to #sign_in' do
          expect(sso_service.new_user_identity.sign_in)
            .to eq(service_name: 'dslogon')
          saml_response_verifying_identity = SAML::ResponseBuilder.saml_response('loa3')
          sso_service_verifying_identity = described_class.new(saml_response_verifying_identity)
          expect(sso_service_verifying_identity.new_user_identity.sign_in)
            .to eq(service_name: 'idme')
          sso_service_verifying_identity.persist_authentication!
          expect(sso_service_verifying_identity.new_user_identity.sign_in)
            .to eq(service_name: 'dslogon')
        end
      end
    end

    context 'dslogon assurance 2' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('dslogon', '2') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon')
      end
    end

   context 'dslogon assurance 3' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('dslogon_loa3', '3') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'dslogon')
      end
    end
  end

  describe 'IDme Identity' do
    context 'idme assurance 1' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('loa1') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme')
      end
    end

    context 'idme assurance 3' do
      let(:saml_response) { SAML::ResponseBuilder.saml_response('loa3') }

      it 'has a #new_user_identity which responds to #sign_in' do
        expect(sso_service.new_user_identity.sign_in)
          .to eq(service_name: 'idme')
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
