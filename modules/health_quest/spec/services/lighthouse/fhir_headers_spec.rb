# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::FHIRHeaders do
  include HealthQuest::Lighthouse::FHIRHeaders

  describe '#auth_header' do
    let(:access_token) { '123abc' }

    it 'has an auth_header key/val' do
      expect(auth_header).to eq({ 'Authorization' => 'Bearer 123abc' })
    end
  end

  describe '#content_type_header' do
    it 'has a content_type_header key/val' do
      expect(content_type_header).to eq({ 'Content-Type' => 'application/fhir+json' })
    end
  end
end
