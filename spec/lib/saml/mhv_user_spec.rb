# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'MHV Logon' do
    let(:authn_context) { 'myhealthevet' }
    let(:account_type)  { 'Basic' }
    let(:highest_attained_loa) { '3' }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: [highest_attained_loa],
        multifactor: [false]
      )
    end

    subject { described_class.new(saml_response) }

    context 'non-premium user' do
      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Basic' },
          mhv_account_type: 'Basic',
          mhv_correlation_id: '12345748',
          mhv_icn: '',
          multifactor: false,
          authn_context: 'myhealthevet'
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'myhealthevet_multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 3 },
            multifactor: true,
            authn_context: 'myhealthevet_multifactor',
            mhv_account_type: 'Basic',
            mhv_correlation_id: '12345748',
            mhv_icn: '',
            sign_in: { service_name: 'myhealthevet', account_type: 'Basic' }
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end
      end

      context 'verifying' do
        let(:authn_context) { 'myhealthevet_loa3' }
        let(:account_type) { 'Advanced' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            first_name: 'Tristan',
            middle_name: '',
            last_name: 'MHV',
            gender: 'M',
            birth_date: '1735-10-30',
            ssn: '111223333',
            zip: nil,
            mhv_account_type: 'Advanced',
            mhv_correlation_id: '12345748',
            mhv_icn: '1012853550V207686',
            loa: { current: 3, highest: 3 },
            sign_in: { service_name: 'myhealthevet', account_type: 'Advanced' },
            multifactor: true,
            authn_context: 'myhealthevet_loa3'
          )
        end

        it 'is changing multifactor' do
          expect(subject).not_to be_changing_multifactor
        end
      end
    end

    context 'premium user' do
      let(:account_type) { 'Premium' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Premium' },
          mhv_account_type: 'Premium',
          mhv_correlation_id: '12345748',
          mhv_icn: '1012853550V207686',
          multifactor: false,
          authn_context: 'myhealthevet'
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'myhealthevet_multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 3, highest: 3 },
            sign_in: { service_name: 'myhealthevet', account_type: 'Premium' },
            multifactor: true,
            authn_context: 'myhealthevet_multifactor',
            mhv_account_type: 'Premium',
            mhv_correlation_id: '12345748',
            mhv_icn: '1012853550V207686'
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end
      end
    end
  end
end
