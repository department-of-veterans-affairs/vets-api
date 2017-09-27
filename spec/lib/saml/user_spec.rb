# frozen_string_literal: true
require 'rails_helper'
require 'saml/user'
require 'ruby-saml'

RSpec.describe SAML::User do
  let(:loa1_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa1_response.xml") }
  let(:loa3_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa3_response.xml") }

  let(:loa1_attrs) do
    {
      'uuid'               => ['1234abcd'],
      'email'              => ['john.adams@whitehouse.gov'],
      'level_of_assurance' => [1]
    }
  end

  let(:loa1_saml_attrs) do
    OneLogin::RubySaml::Attributes.new(loa1_attrs)
  end

  let(:loa3_saml_attrs) do
    OneLogin::RubySaml::Attributes.new(
      loa1_attrs.merge(
        'fname' => ['John'],
        'lname'      => ['Adams'],
        'mname'      => [''],
        'social'     => ['11122333'],
        'gender'     => ['male'],
        'birth_date' => ['1735-10-30'],
        'level_of_assurance' => [3]
      )
    )
  end
  let(:settings) { double('settings', authn_context: 'idme') }
  let(:saml_response) { double('saml_response', settings: settings) }
  let(:described_instance) { described_class.new(saml_response) }

  context 'LOA highest is lower than LOA current' do
    let(:user) { User.new(described_instance) }
    before do
      loa3_saml_attrs['level_of_assurance'] = [1]
      allow(saml_response).to receive(:attributes).and_return(loa3_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa3_xml))
    end

    it 'properly constructs a user' do
      expect(user).to be_valid
    end

    it 'defaults loa.highest to loa.current' do
      expect(user.loa[:highest]).to eq(LOA::THREE)
    end
  end

  describe 'instance method' do
    let(:subject) { described_class.new(saml_response) }
    before do
      allow(saml_response).to receive(:attributes).and_return({})
    end

    context 'changing_multifactor?' do
      MULTIFACTORS = %w(dslogon_multifactor multifactor mhv_multifactor).freeze
      NON_MULTIFACTORS = (%w(mhv dslogon) + LOA::MAPPING.keys + [nil]).freeze

      MULTIFACTORS.each do |example|
        it "responds as true when real_authn_context is #{example}" do
          allow_any_instance_of(SAML::User).to receive(:real_authn_context).and_return(example)
          expect(subject.changing_multifactor?).to be_truthy
        end
      end

      NON_MULTIFACTORS.each do |example|
        it "responds as false when real_authn_context is #{example}" do
          allow_any_instance_of(SAML::User).to receive(:real_authn_context).and_return(example)
          expect(subject.changing_multifactor?).to be_falsey
        end
      end
    end
  end

  context 'when LOA highest is nil' do
    let(:user) { User.new(described_instance) }
    before do
      loa1_saml_attrs['level_of_assurance'] = []
      allow(saml_response).to receive(:attributes).and_return(loa1_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
    end

    it 'properly constructs a user' do
      expect(user).to be_valid
    end
    it 'defaults loa.highest to loa.current' do
      expect(user.loa[:highest]).to eq(LOA::ONE)
    end
    it 'logs a warning' do
      expect(Rails.logger).to receive(:warn).at_least(:once)
      user
    end
  end

  context 'when LOA 1' do
    before do
      allow(saml_response).to receive(:attributes).and_return(loa1_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
    end

    it 'properly constructs a user' do
      expect(User.new(described_instance)).to be_valid
    end
  end

  context 'when LOA 3' do
    before do
      allow(saml_response).to receive(:attributes).and_return(loa3_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa3_xml))
    end

    it 'properly constructs a user' do
      expect(User.new(described_instance)).to be_valid
    end
  end

  context 'when gender is nil' do
    let(:user) { User.new(described_instance) }
    before do
      allow(saml_response).to receive(:attributes).and_return(loa1_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
    end

    it 'properly constructs a user' do
      expect(user).to be_valid
      expect(user.gender).to be_nil
    end
  end
end
