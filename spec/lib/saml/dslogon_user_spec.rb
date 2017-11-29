# frozen_string_literal: true
require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  describe 'DS Logon' do
    let(:saml_response) do
      instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                    decrypted_document: decrypted_document_partial)
    end
    let(:decrypted_document_partial) { REXML::Document.new(dslogon_response) }
    let(:dslogon_response) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/dslogon_response.xml") }

    let(:described_instance) { described_class.new(saml_response) }
    let(:user_identity) { UserIdentity.new(described_instance.to_hash) }

    context 'logging' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => [],
          'dslogon_assurance' => ['1'],
          'dslogon_gender' => [],
          'dslogon_deceased' => [],
          'dslogon_idtype' => [],
          'uuid' => ['5e7465d7c3ba47f3a388d00df1e1a982'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['fake.user@vets.gov'],
          'multifactor' => ['true'],
          'level_of_assurance' => ['3'],
          'dslogon_birth_date' => [],
          'dslogon_fname' => [],
          'dslogon_lname' => [],
          'dslogon_mname' => [],
          'dslogon_idvalue' => []
        )
      end

      it 'does not log warnings to sentry when everything is ok' do
        expect(described_instance).not_to receive(:log_message_to_sentry)
      end

      it 'logs warnings to sentry when loa are nil' do
        allow_any_instance_of(SAML::UserAttributes::DSLogon).to receive(:loa_current).and_return(nil)
        allow_any_instance_of(SAML::UserAttributes::DSLogon).to receive(:loa_highest).and_return(nil)
        allow_any_instance_of(SAML::UserAttributes::DSLogon).to receive(:idme_loa).and_return(nil)
        expect_any_instance_of(described_class).to receive(:log_message_to_sentry).with(
          'Issues in SAML Response - dslogon',
          :warn,
          real_authn_context: 'dslogon',
          authn_context: 'dslogon',
          warnings: 'LOA Current Nil, LOA Highest Nil',
          loa: {
            current: nil,
            highest: nil
          }
        )
        described_instance
      end
    end

    context 'non-premium user' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => [],
          'dslogon_assurance' => ['1'],
          'dslogon_gender' => [],
          'dslogon_deceased' => [],
          'dslogon_idtype' => [],
          'uuid' => ['5e7465d7c3ba47f3a388d00df1e1a982'],
          'dslogon_uuid' => ['1606997570'],
          'email' => ['fake.user@vets.gov'],
          'multifactor' => ['true'],
          'level_of_assurance' => ['3'],
          'dslogon_birth_date' => [],
          'dslogon_fname' => [],
          'dslogon_lname' => [],
          'dslogon_mname' => [],
          'dslogon_idvalue' => []
        )
      end

      it 'properly constructs a user' do
        expect(user_identity).to be_valid
      end

      it 'has email' do
        expect(user_identity.email).to be_present
      end

      it 'has various important attributes' do
        expect(user_identity).to have_attributes(
          uuid: '5e7465d7c3ba47f3a388d00df1e1a982',
          email: 'fake.user@vets.gov',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          zip: nil,
          ssn: nil,
          loa: { current: 1, highest: 3 },
          multifactor: true,
          authn_context: 'dslogon'
        )
      end
    end

    context 'premium user' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => ['SPONSOR'],
          'dslogon_assurance' => ['2'],
          'dslogon_gender' => ['male'],
          'dslogon_deceased' => ['false'],
          'dslogon_idtype' => ['ssn'],
          'uuid' => ['cf0f3deb1b424d3cb4f792e8346a4d71'],
          'dslogon_uuid' => ['1016980877'],
          'email' => ['fake.user@vets.gov'],
          'multifactor' => ['false'],
          'level_of_assurance' => [],
          'dslogon_birth_date' => ['1973-09-03'],
          'dslogon_fname' => ['KENT'],
          'dslogon_lname' => ['WELLS'],
          'dslogon_mname' => ['Mayo'],
          'dslogon_idvalue' => ['796178410']
        )
      end

      it 'properly constructs a user' do
        expect(user_identity.valid?(:loa3_user)).to be_truthy
      end

      it 'has email' do
        expect(user_identity.email).to be_present
      end

      it 'has various important attributes' do
        expect(user_identity).to have_attributes(
          uuid: 'cf0f3deb1b424d3cb4f792e8346a4d71',
          email: 'fake.user@vets.gov',
          first_name: 'KENT',
          middle_name: 'Mayo',
          last_name: 'WELLS',
          gender: 'M',
          birth_date: '1973-09-03',
          zip: nil,
          ssn: '796178410',
          loa: { current: 3, highest: 3 },
          multifactor: false,
          authn_context: 'dslogon',
        )
      end
    end

    context 'premium user with gender (unknown)' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'dslogon_status' => ['SPONSOR'],
          'dslogon_assurance' => ['2'],
          'dslogon_gender' => ['unknown'],
          'dslogon_deceased' => ['false'],
          'dslogon_idtype' => ['ssn'],
          'uuid' => ['cf0f3deb1b424d3cb4f792e8346a4d71'],
          'dslogon_uuid' => ['1016980877'],
          'email' => ['fake.user@vets.gov'],
          'multifactor' => [],
          'level_of_assurance' => [],
          'dslogon_birth_date' => ['1973-09-03'],
          'dslogon_fname' => ['KENT'],
          'dslogon_lname' => ['WELLS'],
          'dslogon_mname' => ['Mayo'],
          'dslogon_idvalue' => ['796178410']
        )
      end

      it 'properly constructs a user' do
        expect(user_identity.multifactor).to be_falsey # when nil
      end
    end
  end
end
