# frozen_string_literal: true

require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  describe 'ID.me' do
    let(:saml_response) do
      instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                    decrypted_document: decrypted_document_partial)
    end
    let(:decrypted_document_partial) { REXML::Document.new(response_partial) }
    let(:response_partial) { File.read("#{::Rails.root}/spec/fixtures/files/saml_responses/#{response_file}") }
    let(:described_instance) { described_class.new(saml_response) }

    context 'LOA1 user' do
      let(:response_file) { 'loa1.xml' }
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['1234abcd'],
          'email'              => ['john.adams@whitehouse.gov'],
          'multifactor'        => ['true'],
          'level_of_assurance' => [3]
        )
      end

      it 'has various important attributes' do
        expect(described_instance.to_hash).to eq(
          uuid: '1234abcd',
          email: 'john.adams@whitehouse.gov',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 3 },
          multifactor: 'true',
          authn_context: nil
        )
      end

      it 'is not changing multifactor' do
        expect(described_instance.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:response_file) { 'multifactor.xml' }

        it 'is changing multifactor' do
          expect(described_instance.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA3 user' do
      let(:response_file) { 'loa3.xml' }
      let(:saml_attributes) do
        OneLogin::RubySaml::Attributes.new(
          'uuid'               => ['1234abcd'],
          'email'              => ['john.adams@whitehouse.gov'],
          'fname'              => ['John'],
          'lname'              => ['Adams'],
          'mname'              => [''],
          'social'             => ['11122333'],
          'gender'             => ['male'],
          'birth_date'         => ['1735-10-30'],
          'level_of_assurance' => [3],
          'multifactor'        => ['true']
        )
      end

      it 'returns loa current 1 if KeyError in LOA::MAPPING lookup for loa_current' do
        stub_const('LOA::MAPPING', {})
        expect_any_instance_of(SAML::UserAttributes::IdMe)
          .to receive(:loa_current).exactly(3).times.and_call_original
        expect_any_instance_of(SAML::UserAttributes::IdMe).to receive(:log_message_to_sentry).once
        expect(described_instance.to_hash.slice(:loa))
          .to eq({loa: {current: 1, highest: 3}})
      end

      it 'has various important attributes' do
        expect(described_instance.to_hash).to eq(
          uuid: '1234abcd',
          email: 'john.adams@whitehouse.gov',
          first_name: 'John',
          middle_name: '',
          last_name: 'Adams',
          gender: 'M',
          birth_date: '1735-10-30',
          ssn: '11122333',
          zip: nil,
          loa: { current: 3, highest: 3 },
          multifactor: 'true',
          authn_context: nil
        )
      end

      it 'is not changing multifactor' do
        expect(described_instance.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:response_file) { 'multifactor.xml' }

        it 'is changing multifactor' do
          expect(described_instance.changing_multifactor?).to be_truthy
        end
      end
    end
  end
end
