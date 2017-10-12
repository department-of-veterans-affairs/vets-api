# frozen_string_literal: true
require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  describe 'MHV Logon' do
    let(:saml_response) do
      instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                    decrypted_document: decrypted_document_partial)
    end
    let(:decrypted_document_partial) { REXML::Document.new(mhv_response) }
    let(:mhv_response) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/mhv_response.xml") }

    context 'non-premium user' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'mhv_icn' => ['1012853550V207686'],
          'mhv_profile' => ['{"accountType":"Advanced","availableServices":{"1":"Blue Button self entered data."}}'],
          'mhv_uuid' => ['12345748'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => ['true'],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'level_of_assurance' => []
        )
      end
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
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          zip: nil,
          ssn: nil,
          loa: { current: 1, highest: 1 },
          multifactor: 'true',
          authn_context: 'myhealthevet',
          last_signed_in: frozen_time,
          mhv_last_signed_in: nil
        )
      end
    end

    context 'premium user' do
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'mhv_icn' => ['1012853550V207686'],
          # rubocop:disable LineLength
          'mhv_profile' => ['{"accountType":"Premium","availableServices":{"21":"VA Medications","4":"Secure Messaging","3":"VA Allergies","2":"Rx Refill","12":"Blue Button (all VA data)","1":"Blue Button self entered data.","11":"Blue Button (DoD) Military Service Information"}}'],
          # rubocop:enable LineLength
          'mhv_uuid' => ['12345748'],
          'email' => ['kam+tristanmhv@adhocteam.us'],
          'multifactor' => ['true'],
          'uuid' => ['0e1bb5723d7c4f0686f46ca4505642ad'],
          'level_of_assurance' => []
        )
      end
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
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          loa: { current: 3, highest: 3 },
          multifactor: 'true',
          authn_context: 'myhealthevet',
          last_signed_in: frozen_time,
          mhv_last_signed_in: nil
        )
      end
    end
  end
end
