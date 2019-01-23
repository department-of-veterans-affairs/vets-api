# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'ID.me' do
    let(:authn_context) { LOA::IDME_LOA1 }
    let(:account_type)  { 'N/A' }
    let(:highest_attained_loa) { '1' }

    let(:saml_response) do
      build_saml_response(
        authn_context: authn_context,
        account_type: account_type,
        level_of_assurance: [highest_attained_loa],
        multifactor: [false]
      )
    end
    subject { described_class.new(saml_response) }

    context 'LOA1 user' do
      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 1 },
          multifactor: false,
          authn_context: LOA::IDME_LOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 1 },
            birth_date: nil,
            first_name: nil,
            last_name: nil,
            middle_name: nil,
            gender: nil,
            ssn: nil,
            zip: nil,
            multifactor: true,
            authn_context: 'multifactor'
          )
        end

        it 'is changing multifactor' do
          expect(subject.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA1 previously verified' do
      let(:highest_attained_loa) { '3' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 3 },
          multifactor: false,
          authn_context: LOA::IDME_LOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'has various important attributes' do
          expect(subject.to_hash).to eq(
            uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
            email: 'kam+tristanmhv@adhocteam.us',
            loa: { current: 1, highest: 3 },
            birth_date: nil,
            first_name: nil,
            last_name: nil,
            middle_name: nil,
            gender: nil,
            ssn: nil,
            zip: nil,
            multifactor: true,
            authn_context: 'multifactor'
          )
        end

        it 'is changing multifactor' do
          expect(subject.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA3 user' do
      let(:authn_context) { LOA::IDME_LOA3 }
      let(:highest_attained_loa) { '3' }

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
          loa: { current: 3, highest: 3 },
          multifactor: true,
          authn_context: LOA::IDME_LOA3
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end
    end
  end
end
