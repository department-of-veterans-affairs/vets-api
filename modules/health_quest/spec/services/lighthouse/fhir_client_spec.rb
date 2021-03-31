# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Lighthouse::FHIRClient do
  include HealthQuest::Lighthouse::FHIRClient

  describe '#headers' do
    it 'raises NotImplementedError' do
      expect { headers }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#api_query_path' do
    it 'raises NotImplementedError' do
      expect { api_query_path }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#client' do
    let(:headers) { { 'X-VAMF-JWT' => 'abc123' } }
    let(:api_query_path) { '/services/pgd/v0/r4' }

    it 'has a fhir_client' do
      expect(client).to be_an_instance_of(FHIR::Client)
    end
  end

  describe '#url' do
    let(:api_query_path) { '/services/pgd/v0/r4' }

    it 'has a pgd path' do
      expect(url).to match(Settings.hqva_mobile.lighthouse.pgd_path)
    end
  end
end
