# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::FHIRClient do
  include HealthQuest::PatientGeneratedData::FHIRClient

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
      expect(url).to match(Settings.hqva_mobile.lighthouse.pgd_path)
    end
  end
end
