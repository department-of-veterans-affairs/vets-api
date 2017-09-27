# frozen_string_literal: true
require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  let(:saml_response) do
    instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                  decrypted_document: decrypted_document_partial)
  end
  let(:decrypted_document_partial) { REXML::Document.new(dslogon_response) }
  let(:dslogon_response) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/dslogon_response.xml") }
  let(:saml_attributes) do
    OneLogin::RubySaml::Attributes.new(
      'dslogon_status' => ['SPONSOR'],
      'dslogon_assurance' => ['2'],
      'dslogon_gender' => ['male'],
      'dslogon_deceased' => ['false'],
      'dslogon_birth_date' => ['1973-09-03'],
      'dslogon_fname' => ['KENT'],
      'dslogon_mname' => ['Mayo'],
      'dslogon_lname' => ['WELLS'],
      'dslogon_idtype' => ['ssn'],
      'dslogon_idvalue' => ['796178410'],
      'uuid' => ['d09ae45773f4409c943ce85f668a527d'],
      'dslogon_uuid' => ['1016980877'],
      'email' => ['vets.gov.user+kent.wells@gmail.com'],
      'multifactor' => ['true'],
      'level_of_assurance' => [3]
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
        uuid: 'd09ae45773f4409c943ce85f668a527d',
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
