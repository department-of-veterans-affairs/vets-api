# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'
require 'saml/user'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'MHV Logon' do
    subject { described_class.new(saml_response) }

    let(:authn_context) { 'myhealthevet' }
    let(:highest_attained_loa) { '3' }
    let(:existing_saml_attributes) { nil }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        level_of_assurance: [highest_attained_loa],
        attributes: saml_attributes,
        existing_attributes: existing_saml_attributes
      )
    end

    context 'non-premium user' do
      # TODO: level_of_assurance for non-proofed MHV should be 0,
      # but that doesn't match existing spec behavior
      let(:saml_attributes) { build(:mhv_basic, level_of_assurance: [highest_attained_loa]) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Basic' },
          mhv_account_type: 'Basic',
          mhv_correlation_id: '12345748',
          mhv_icn: '',
          multifactor: false,
          sec_id: nil,
          authn_context: 'myhealthevet'
        )
      end

      it 'is not changing multifactor' do
        expect(subject).not_to be_changing_multifactor
      end

      context 'multifactor' do
        let(:authn_context) { 'myhealthevet_multifactor' }
        # TODO: level_of_assurance for non-proofed MHV should be 0,
        # but that doesn't match existing spec behavior
        let(:saml_attributes) { build(:mhv_basic, multifactor: [true], level_of_assurance: [highest_attained_loa]) }
        let(:existing_saml_attributes) { build(:mhv_basic, multifactor: [false], level_of_assurance: ['3']) }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            loa: { current: 1, highest: 3 },
            multifactor: true,
            sec_id: nil,
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
        let(:saml_attributes) { build(:mhv_loa3, multifactor: [true], level_of_assurance: ['3']) }
        let(:existing_saml_attributes) { build(:mhv_advanced, multifactor: [true], level_of_assurance: ['3']) }

        it 'merges existing MHV identity with ID.me identity' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            first_name: 'Tristan',
            middle_name: '',
            last_name: 'MHV',
            gender: 'M',
            birth_date: '1735-10-30',
            ssn: '111223333',
            zip: nil,
            sec_id: nil,
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
      let(:saml_attributes) { build(:mhv_premium, multifactor: [false], level_of_assurance: [highest_attained_loa]) }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 3, highest: 3 },
          sign_in: { service_name: 'myhealthevet', account_type: 'Premium' },
          sec_id: nil,
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
        let(:saml_attributes) { build(:mhv_premium, multifactor: [true], level_of_assurance: [highest_attained_loa]) }
        let(:existing_saml_attributes) do
          build(:mhv_premium,
                multifactor: [false],
                level_of_assurance: [highest_attained_loa])
        end

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            idme_uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            loa: { current: 3, highest: 3 },
            sign_in: { service_name: 'myhealthevet', account_type: 'Premium' },
            multifactor: true,
            authn_context: 'myhealthevet_multifactor',
            sec_id: nil,
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
