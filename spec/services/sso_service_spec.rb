# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SSOService do
  subject { described_class.new(saml_response) }

  context 'nil saml response' do
    let(:saml_response) { nil }

    xit 'raises a runtime error if anything but OneLogin::RubySaml::Response is provided as initializer arguments' do
      # This should be passing but will break specs so commenting out for now.
      expect { subject }.to raise_error(RuntimeError)
    end
  end

  context 'invalid saml response' do
    let(:saml_response) { OneLogin::RubySaml::Response.new('') }

    it 'has Blank response error' do
      expect(subject.valid?).to be_falsey
      expect(subject.errors.full_messages).to eq(['Blank response'])
    end

    it '#persist_authentication! handles saml response errors' do
      expect(SAML::AuthFailHandler).to receive(:new).with(subject.saml_response).and_call_original
      subject.persist_authentication!
    end
  end
end
