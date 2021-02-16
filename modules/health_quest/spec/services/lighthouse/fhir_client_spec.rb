# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::FHIRClient do
  include HealthQuest::Lighthouse::FHIRClient

  describe '#headers' do
    it 'raises NotImplementedError' do
      expect { headers }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#lighthouse_api_path' do
    it 'raises NotImplementedError' do
      expect { lighthouse_api_path }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#client' do
    let(:headers) { { 'X-VAMF-JWT' => 'abc123' } }
    let(:lighthouse_api_path) { '/lighthouse/api/path' }

    it 'has a fhir_client' do
      expect(client).to be_an_instance_of(FHIR::Client)
    end
  end
end
