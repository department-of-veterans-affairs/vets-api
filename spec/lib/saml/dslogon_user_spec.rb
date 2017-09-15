# frozen_string_literal: true
require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  let(:params) { { SAMLResponse: File.read("#{::Rails.root}/spec/fixtures/files/saml_responses/dslogon.params") } }
  let(:saml_settings) { build(:settings_no_context) }
  let(:saml_response) { OneLogin::RubySaml::Response.new(params[:SAMLResponse], settings: saml_settings) }
  let(:described_instance) { described_class.new(saml_response) }

  context 'LOA highest is lower than LOA current' do
    let(:user) { User.new(described_instance) }
    let(:cert) { File.read 'spec/support/certificates/ruby-saml.crt' }
    let(:key) { File.read 'spec/support/certificates/ruby-saml.key' }

    around(:each) do |example|
      with_settings(Settings.saml, cert: cert, key: key) do
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
        uuid: '2d95596317cd45a3afd513cd15a980fb',
        first_name: 'KENT',
        middle_name: 'Mayo',
        last_name: 'WELLS',
        gender: 'M',
        birth_date: '1973-09-03',
        zip: nil,
        ssn: '796178410',
        loa: { current: 3, highest: 3 },
        multifactor: 'false',
        mhv_last_signed_in: nil
      )
    end
  end
end
