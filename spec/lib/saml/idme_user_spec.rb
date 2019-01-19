# frozen_string_literal: true

require 'rails_helper'
require 'support/saml/response_builder'

RSpec.describe SAML::User do
  include SAML::ResponseBuilder

  describe 'ID.me' do
    let(:authn_context) { SAML::ResponseBuilder::IDMELOA1 }
    let(:saml_attributes) { build_saml_attributes(authn_context: authn_context) }
    let(:saml_response) { build_saml_response(authn_context: authn_context, attributes: saml_attributes) }
    subject { described_class.new(saml_response) }

    context 'LOA1 user' do
      context 'add additional context when no decrypted document' do
        let(:saml_response) do
          instance_double(OneLogin::RubySaml::Response, attributes: saml_attributes,
                                                        response: 'base64decoded-stuff',
                                                        decrypted_document: decrypted_document_partial)
        end
        let(:decrypted_document_partial) { REXML::Document.new(response_partial) }
        let(:response_file) { 'loa1.xml' }
        let(:response_partial) { File.read("#{::Rails.root}/spec/fixtures/files/saml_responses/#{response_file}") }

        it 'adds additional context for NoMethodError' do
          allow(REXML::XPath).to receive(:first).and_raise(NoMethodError)
          expect(Raven).to receive(:extra_context).with(
            base64encodedpayload: Base64.encode64('base64decoded-stuff'),
            attributes: saml_attributes.to_h
          )
          expect(Raven).to receive(:tags_context).with(
            controller_name: 'sessions', sign_in_method: 'not-signed-in:error'
          )
          expect { subject }.to raise_error(NoMethodError)
        end
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          sign_in: { service_name: 'idme', account_type: 'N/A', id_proof_type: 'not-verified' },
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 1 },
          multifactor: false,
          authn_context: SAML::ResponseBuilder::IDMELOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'is changing multifactor' do
          expect(subject.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA1 previously verified' do
      let(:saml_attributes) { build_saml_attributes(authn_context: authn_context, level_of_assurance: ['3']) }
      let(:saml_response) do
        build_saml_response(authn_context: authn_context, level_of_assurance: ['3'], attributes: saml_attributes)
      end

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: nil,
          middle_name: nil,
          last_name: nil,
          gender: nil,
          birth_date: nil,
          sign_in: { service_name: 'idme', account_type: 'N/A', id_proof_type: 'not-verified' },
          ssn: nil,
          zip: nil,
          loa: { current: 1, highest: 3 },
          multifactor: false,
          authn_context: SAML::ResponseBuilder::IDMELOA1
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end

      context 'multifactor' do
        let(:authn_context) { 'multifactor' }

        it 'is changing multifactor' do
          expect(subject.changing_multifactor?).to be_truthy
        end
      end
    end

    context 'LOA3 user' do
      let(:authn_context) { SAML::ResponseBuilder::IDMELOA3 }

      it 'has various important attributes' do
        expect(subject.to_hash).to eq(
          uuid: '0e1bb5723d7c4f0686f46ca4505642ad',
          email: 'kam+tristanmhv@adhocteam.us',
          first_name: 'Tristan',
          middle_name: '',
          last_name: 'MHV',
          gender: 'M',
          birth_date: '1735-10-30',
          sign_in: { service_name: 'idme', account_type: 'N/A', id_proof_type: 'idme' },
          ssn: '111223333',
          zip: nil,
          loa: { current: 3, highest: 3 },
          multifactor: true,
          authn_context: SAML::ResponseBuilder::IDMELOA3
        )
      end

      it 'is not changing multifactor' do
        expect(subject.changing_multifactor?).to be_falsey
      end
    end
  end
end
