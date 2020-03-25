# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'SSOe' do
    subject { described_class.new(saml_response) }

    let(:authn_context) { LOA::IDME_LOA1_VETS }
    let(:account_type)  { '1' }
    let(:highest_attained_loa) { '1' }
    let(:multifactor) { false }
    let(:existing_saml_attributes) { nil }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes,
        issuer: 'https://int.eauth.va.gov/FIM/sps/saml20fedCSP/saml20'
      )
    end

    context 'mapped attributes' do
      let(:saml_attributes) do
        build(:ssoe_idme_loa1,
              va_eauth_firstname: ['NOT_FOUND'],
              va_eauth_lastname: ['NOT_FOUND'],
              va_eauth_gender: ['NOT_FOUND'])
      end

      it 'maps NOT_FOUND attributes to nil' do
        expect(subject.to_hash[:first_name]).to be_nil
        expect(subject.to_hash[:last_name]).to be_nil
        expect(subject.to_hash[:gender]).to be_nil
      end
    end

    context 'male gender user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1, va_eauth_gender: ['male']) }

      it 'maps male gender value' do
        expect(subject.to_hash[:gender]).to eq('M')
      end
    end

    context 'female gender user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1, va_eauth_gender: ['female']) }

      it 'maps female gender value' do
        expect(subject.to_hash[:gender]).to eq('F')
      end
    end

    context 'unproofed IDme LOA1 user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1_unproofed) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: false,
          loa: { current: 1, highest: 1 },
          sign_in: { service_name: 'idme', account_type: 1 },
          sec_id: nil,
          authenticated_by_ssoe: true
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'previously proofed IDme LOA1 user' do
      let(:saml_attributes) { build(:ssoe_idme_loa1) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: nil,
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: true,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 1 },
          sec_id: nil,
          authenticated_by_ssoe: true
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'IDme LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:saml_attributes) { build(:ssoe_idme_loa3) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          authn_context: authn_context,
          birth_date: '19690407',
          first_name: 'JERRY',
          last_name: 'GPKTESTNINE',
          middle_name: nil,
          gender: 'M',
          ssn: '666271152',
          zip: nil,
          mhv_icn: '1008830476V316605',
          mhv_correlation_id: nil,
          dslogon_edipi: nil,
          uuid: '54e78de6140d473f87960f211be49c08',
          email: 'vets.gov.user+262@example.com',
          idme_uuid: '54e78de6140d473f87960f211be49c08',
          multifactor: true,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'idme', account_type: 3 },
          sec_id: '1008830476',
          authenticated_by_ssoe: true
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end
    end

    context 'MHV non premium user' do
      let(:authn_context) { 'myhealthevet' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_advanced) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          dslogon_edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 1 },
          sec_id: nil,
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'MHV non premium user who verifies' do
      let(:authn_context) { 'myhealthevet_loa3' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_loa3) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19881124',
          authn_context: authn_context,
          dslogon_edipi: nil,
          first_name: 'ALEX',
          last_name: 'MAC',
          middle_name: nil,
          gender: 'F',
          ssn: '230595111',
          zip: nil,
          mhv_icn: '1013183292V131165',
          mhv_correlation_id: nil,
          uuid: '881571066e5741439652bc80759dd88c',
          email: 'alexmac_0@example.com',
          idme_uuid: '881571066e5741439652bc80759dd88c',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 3 },
          sec_id: '1013183292',
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'MHV non premium user who adds multifactor' do
      let(:authn_context) { 'myhealthevet_multifactor' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '1' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_basic_multifactor) }
      let(:multifactor) { false }
      let(:existing_saml_attributes) { build(:ssoe_idme_mhv_basic_singlefactor) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          dslogon_edipi: nil,
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          uuid: '72782a87a807407f83e8a052d804d7f7',
          email: 'pv+mhvtestb@example.com',
          idme_uuid: '72782a87a807407f83e8a052d804d7f7',
          loa: { current: 1, highest: 1 },
          sign_in: { service_name: 'myhealthevet', account_type: 1 },
          sec_id: nil,
          multifactor: true,
          authenticated_by_ssoe: true
        )
      end

      it 'is changing multifactor' do
        expect(subject).to be_changing_multifactor
      end
    end

    context 'MHV premium user' do
      let(:authn_context) { 'myhealthevet' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_premium) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19770307',
          authn_context: authn_context,
          dslogon_edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: nil,
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: nil,
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'k+tristanmhv@example.com',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 3 },
          sec_id: '1012853550',
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'MHV premium user no idme uuid' do
      let(:authn_context) { 'myhealthevet' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_mhv_premium, va_eauth_uid: ['NOT_FOUND'], va_eauth_csid: ['NOT_FOUND'], va_eauth_gcIds: ['']) }
      let(:multifactor) { true }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19770307',
          authn_context: authn_context,
          dslogon_edipi: '2107307560',
          first_name: 'TRISTAN',
          last_name: 'GPTESTSYSTWO',
          middle_name: nil,
          gender: 'M',
          ssn: '666811850',
          zip: nil,
          mhv_icn: '1012853550V207686',
          mhv_correlation_id: nil,
          uuid: Digest::UUID.uuid_v3('sec-id', '1012853550').tr('-', ''),
          email: 'k+tristanmhv@example.com',
          idme_uuid: nil,
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 3 },
          sec_id: '1012853550',
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'DSLogon non premium user' do
      let(:authn_context) { 'dslogon' }
      let(:account_type) { '1' }
      let(:highest_attained_loa) { '3' }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level1) }

      xit 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: nil,
          authn_context: authn_context,
          dslogon_edipi: '1606997570',
          first_name: nil,
          last_name: nil,
          middle_name: nil,
          gender: nil,
          ssn: nil,
          zip: nil,
          mhv_icn: nil,
          mhv_correlation_id: nil,
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: 1 },
          sec_id: nil,
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'DSLogon premium user without multifactor' do
      let(:authn_context) { 'dslogon' }
      let(:account_type) { '3' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2_singlefactor) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19510604',
          authn_context: authn_context,
          dslogon_edipi: '2106798217',
          first_name: 'BRANDIN',
          last_name: 'MILLER-NIETO',
          middle_name: 'BRANSON',
          gender: 'M',
          ssn: '666016789',
          zip: nil,
          mhv_icn: '1013173963V366678',
          mhv_correlation_id: nil,
          uuid: '363761e8857642f7b77ef7d99200e711',
          email: 'iam.tester@example.com',
          idme_uuid: '363761e8857642f7b77ef7d99200e711',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: 3 },
          sec_id: '1013173963',
          multifactor: false,
          authenticated_by_ssoe: true
        )
      end

      it 'does not trigger upleveling' do
        loa = subject.to_hash[:loa]
        expect((loa[:highest] > loa[:current])).to be false
      end
    end

    context 'DSLogon premium user' do
      let(:authn_context) { 'dslogon' }
      let(:account_type) { '3' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19560710',
          authn_context: authn_context,
          dslogon_edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: 3 },
          sec_id: '0000028007',
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end

    context 'DSLogon premium user with idme uuid in gcIds' do
      let(:authn_context) { 'dslogon' }
      let(:account_type) { '3' }
      let(:highest_attained_loa) { '3' }
      let(:multifactor) { true }
      let(:saml_attributes) { build(:ssoe_idme_dslogon_level2, va_eauth_uid: ['0000028007'], va_eauth_csid: ['NOT_FOUND']) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '19560710',
          authn_context: authn_context,
          dslogon_edipi: '1005169255',
          first_name: 'JOHNNIE',
          last_name: 'WEAVER',
          middle_name: 'LEONARD',
          gender: 'M',
          ssn: '796123607',
          zip: '20571-0001',
          mhv_icn: '1012740600V714187',
          mhv_correlation_id: nil,
          uuid: '1655c16aa0784dbe973814c95bd69177',
          email: 'Test0206@gmail.com',
          idme_uuid: '1655c16aa0784dbe973814c95bd69177',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'dslogon', account_type: 3 },
          sec_id: '0000028007',
          multifactor: multifactor,
          authenticated_by_ssoe: true
        )
      end
    end
  end
end
