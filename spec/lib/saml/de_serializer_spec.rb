# frozen_string_literal: true
require 'rails_helper'
require 'saml/de_serializer'

RSpec.describe SAML::DeSerializer do
  let(:loa1_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa1_response.xml") }
  let(:loa3_xml) { File.read("#{::Rails.root}/spec/fixtures/files/saml_xml/loa3_response.xml") }
  let(:loa1_saml_attrs) do
    {
      'uuid'               => ['1234abcd'],
      'email'              => ['john.adams@whitehouse.gov'],
      'level_of_assurance' => [1]
    }
  end
  let(:loa3_saml_attrs) do
    loa1_saml_attrs.merge({

      'fname'      => ['John'],
      'lname'      => ['Adams'],
      'mname'      => [''],
      'social'     => ['11122333'],
      'gender'     => ['male'],
      'birth_date' => ['1735-10-30'],
      'level_of_assurance' => [3]
    })
  end
  let(:saml_response) { double('saml_response') }
  let(:described_instance) { described_class.new(double('saml_response')) }

  before do
    described_instance.instance_variable_set(:@saml_response, saml_response)
  end


  context 'LOA highest is lower than LOA current' do
    let(:user) { User.new(described_instance.user_attributes) }
    before do
      loa3_saml_attrs['level_of_assurance'] = [1]
      allow(saml_response).to receive_message_chain(:attributes, :all, :to_h).and_return(loa3_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa3_xml))
    end

    it 'properly constructs a user' do
      expect(user).to be_valid
    end
    it 'defaults loa.highest o loa.current' do
      expect(user.loa[:highest]).to eq(LOA::THREE)
    end
  end

  context 'when LOA highest is nil' do
    let(:user) { User.new(described_instance.user_attributes) }
    before do
      loa1_saml_attrs['level_of_assurance'] = []
      allow(saml_response).to receive_message_chain(:attributes, :all, :to_h).and_return(loa1_saml_attrs)
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
      described_instance.user_attributes
    end
  end

  context 'when LOA 1' do
    before do
      allow(saml_response).to receive_message_chain(:attributes, :all, :to_h).and_return(loa1_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
    end

    it 'properly constructs a user' do
      expect(User.new(described_instance.user_attributes)).to be_valid
    end
  end

  context 'when LOA 3' do
    before do
      allow(saml_response).to receive_message_chain(:attributes, :all, :to_h).and_return(loa3_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa3_xml))
    end

    it 'properly constructs a user' do
      expect(User.new(described_instance.user_attributes)).to be_valid
    end
  end

  context 'when gender is nil' do
    let(:user) { User.new(described_instance.user_attributes) }
    before do
      loa1_saml_attrs['gender'] = nil
      allow(saml_response).to receive_message_chain(:attributes, :all, :to_h).and_return(loa1_saml_attrs)
      allow(saml_response).to receive(:decrypted_document).and_return(REXML::Document.new(loa1_xml))
    end

    it 'properly constructs a user' do
      expect(user).to be_valid
      expect(user.gender).to be_nil
    end
  end
end