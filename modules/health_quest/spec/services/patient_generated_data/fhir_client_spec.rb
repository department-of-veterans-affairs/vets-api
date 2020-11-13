# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::FhirClient do
  include HealthQuest::PatientGeneratedData::FhirClient

  describe '#accept_headers' do
    it 'has default Accept header' do
      expect(accept_headers).to eq({ 'Accept' => 'application/json+fhir' })
    end
  end

  describe '#headers' do
    it 'raises NotImplementedError' do
      expect { headers }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#client' do
    let(:headers) { { 'X-VAMF-JWT' => 'abc123' } }

    it 'has a fhir_client' do
      expect(client).to be_an_instance_of(FHIR::Client)
    end
  end

  describe '#url' do
    it 'has a pgd path' do
      expect(url).to match('/smart-pgd-fhir/v1')
    end
  end
end
