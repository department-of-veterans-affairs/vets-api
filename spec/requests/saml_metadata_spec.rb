# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'SAML Metadata', type: :request do
  let(:rubysaml_settings) { FactoryBot.build(:rubysaml_settings) }

  before do
    allow_any_instance_of(ApplicationController).to receive(:saml_settings).and_return(rubysaml_settings)
  end

  it 'Provides XML SAML metadata' do
    get '/saml/metadata'
    assert_response :success

    xml = Nokogiri::XML(response.body)

    entity_id = xml.at_xpath('//md:EntityDescriptor/@entityID', 'md' => 'urn:oasis:names:tc:SAML:2.0:metadata')
    expect(entity_id.value).to eq(Settings.saml.issuer)
  end

  context 'when a new cert exists for rollover' do
    let(:rubysaml_settings) { FactoryBot.build(:rubysaml_settings, :rollover_cert) }

    before do
      allow_any_instance_of(ApplicationController).to receive(:saml_settings).and_return(rubysaml_settings)
    end

    it 'provides two certificates' do
      get '/saml/metadata'
      assert_response :success

      xml = Nokogiri::XML(response.body)

      cert_nodes = xml.xpath('//ds:X509Certificate', 'ds' => 'http://www.w3.org/2000/09/xmldsig#')
      expect(cert_nodes.size).to eq(2)
    end
  end
end
