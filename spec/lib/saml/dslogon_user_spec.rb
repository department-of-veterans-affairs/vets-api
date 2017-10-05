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

      context 'LOA highest is lower than LOA current' do
        let(:described_instance) { described_class.new(saml_response) }
        let(:user) { User.new(described_instance) }
        let(:frozen_time) { Time.current }

        around(:each) do |example|
          Timecop.freeze(frozen_time) do
            example.run
          end
        end

        it 'properly constructs a user' do
          expect(user).to be_valid
        end

        it 'has email' do
          expect(user.email).to be_present
        end

        it 'has various important attributes' do
          expect(user).to have_attributes(
            uuid: '5e7465d7c3ba47f3a388d00df1e1a982',
            first_name: nil,
            middle_name: nil,
            last_name: nil,
            gender: nil,
            birth_date: nil,
            zip: nil,
            ssn: nil,
            loa: { current: 1, highest: 3 },
            multifactor: 'true',
            authn_context: 'dslogon',
            last_signed_in: frozen_time,
            mhv_last_signed_in: nil
          )
        end
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
          'multifactor' => ['true'],
          'level_of_assurance' => [],
          'dslogon_birth_date' => ['1973-09-03'],
          'dslogon_fname' => ['KENT'],
          'dslogon_lname' => ['WELLS'],
          'dslogon_mname' => ['Mayo'],
          'dslogon_idvalue' => ['796178410']
        )
      end

      context 'LOA highest is lower than LOA current' do
        let(:described_instance) { described_class.new(saml_response) }
        let(:user) { User.new(described_instance) }
        let(:frozen_time) { Time.current }

        around(:each) do |example|
          Timecop.freeze(frozen_time) do
            example.run
          end
        end

        it 'properly constructs a user' do
          expect(user).to be_valid
        end

        it 'has email' do
          expect(user.email).to be_present
        end

        it 'has various important attributes' do
          expect(user).to have_attributes(
            uuid: 'cf0f3deb1b424d3cb4f792e8346a4d71',
            first_name: 'KENT',
            middle_name: 'Mayo',
            last_name: 'WELLS',
            gender: 'M',
            birth_date: '1973-09-03',
            zip: nil,
            ssn: '796178410',
            loa: { current: 3, highest: 3 },
            multifactor: 'true',
            authn_context: 'dslogon',
            last_signed_in: frozen_time,
            mhv_last_signed_in: nil
          )
        end
      end
    end
  end
end
