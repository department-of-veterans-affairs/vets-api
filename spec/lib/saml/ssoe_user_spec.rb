# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'SSOe' do
    # TODO: change if necessary
    let(:authn_context) { 'ssoe' }
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

    context 'LOA1 user' do
      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          dslogon_edipi: '1606997570',
          birth_date: nil,
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
          multifactor: false,
          loa: { current: 1, highest: 3 },
          sign_in: { service_name: 'ssoe', account_type: '3' },
          authn_context: 'ssoe'
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end
    end

    context 'LOA3 user' do
      let(:account_type) { '3' }
      let(:highest_attained_loa) { '3' }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          birth_date: '1735-10-30',
          dslogon_edipi: '1606997570',
          first_name: 'Tristan',
          last_name: 'MHV',
          middle_name: '',
          gender: 'M',
          ssn: '111223333',
          zip: '12345',
          mhv_icn: '0000',
          mhv_correlation_id: '0000',
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          loa: { current: 3, highest: 3 },
          # TODO: validate when/how this attribute is being used
          sign_in: { service_name: 'ssoe', account_type: '3' },
          multifactor: false,
          authn_context: 'ssoe'
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end
    end
  end
end
