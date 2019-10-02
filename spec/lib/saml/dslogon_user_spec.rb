# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'DS Logon' do
    let(:authn_context) { 'dslogon' }
    let(:account_type)  { '1' }
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
          dslogon_edipi: '1606997570',
          birth_date: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          multifactor: false,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: '1' },
          authn_context: 'dslogon'
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'dslogon_multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 3 },
            sign_in: { service_name: 'dslogon', account_type: '1' },
            birth_date: nil,
            first_name: nil,
            last_name: nil,
            middle_name: nil,
            gender: nil,
            ssn: nil,
            multifactor: true,
            authn_context: 'dslogon_multifactor',
            dslogon_edipi: '1606997570'
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end
      end

      context 'verifying' do
        let(:authn_context) { 'dslogon_loa3' }

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
            dslogon_edipi: '1606997570',
            loa: { current: 3, highest: 3 },
            sign_in: { service_name: 'dslogon', account_type: '1' },
            multifactor: true,
            authn_context: 'dslogon_loa3'
          )
        end

        it 'is changing multifactor' do
          expect(subject).not_to be_changing_multifactor
        end
      end
    end

    context 'premium user' do
      let(:account_type) { '2' }
      let(:highest_attained_loa) { nil }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1735-10-30',
          dslogon_edipi: '1606997570',
          first_name: 'Tristan',
          last_name: 'MHV',
          middle_name: '',
          gender: 'M',
          ssn: '111223333',
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: '2' },
          multifactor: false,
          authn_context: 'dslogon'
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'dslogon_multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 3, highest: 3 },
            sign_in: { service_name: 'dslogon', account_type: '2' },
            birth_date: '1735-10-30',
            first_name: 'Tristan',
            last_name: 'MHV',
            middle_name: '',
            gender: 'M',
            ssn: '111223333',
            multifactor: true,
            authn_context: 'dslogon_multifactor',
            dslogon_edipi: '1606997570'
          )
        end

        it 'is changing multifactor' do
          expect(subject).to be_changing_multifactor
        end
      end
    end
  end
end
