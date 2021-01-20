# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Common::IdentityMetaInfo do
  include HealthQuest::PatientGeneratedData::Common::IdentityMetaInfo

  subject { described_class }

  let(:resource) { Object.new.extend(subject) }
  let(:identifier_type_hash) do
    {
      coding: [
        {
          system: 'https://pki.dmdc.osd.mil/milconnect',
          code: 'RESOURCEID',
          userSelected: false
        }
      ]
    }
  end

  describe '#identifier' do
    it 'raises NotImplementedError' do
      expect { identifier }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#meta' do
    it 'raises NotImplementedError' do
      expect { meta }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#identifier_value' do
    it 'raises NotImplementedError' do
      expect { identifier_value }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe '#identifier_code' do
    it 'raises NotImplementedError' do
      expect { identifier_code }.to raise_error(NoMethodError, /NotImplementedError/)
    end
  end

  describe 'Constants' do
    it 'has a SYSTEM_ID' do
      expect(subject::SYSTEM_ID).to eq('urn:uuid:2.16.840.1.113883.4.349')
    end

    it 'has a CODING_SYSTEM' do
      expect(subject::CODING_SYSTEM).to eq('https://pki.dmdc.osd.mil/milconnect')
    end

    it 'has a META_SYSTEM' do
      expect(subject::META_SYSTEM).to eq('https://wiki.mobilehealth.va.gov/display/PGDMS/Client+Provenance+Mapping')
    end

    it 'has a META_CODE' do
      expect(subject::META_CODE).to eq('vagov-a0e116eb-faa1-4703-aafe-1a270128607a')
    end

    it 'has a META_DISPLAY' do
      expect(subject::META_DISPLAY).to eq('VA GOV CLIPBOARD')
    end
  end

  describe '#set_meta' do
    it 'returns the models meta' do
      meta_hash = {
        'tag' => [
          {
            system: 'https://wiki.mobilehealth.va.gov/display/PGDMS/Client+Provenance+Mapping',
            code: 'vagov-a0e116eb-faa1-4703-aafe-1a270128607a',
            display: 'VA GOV CLIPBOARD'
          }
        ]
      }
      allow(resource).to receive(:meta).and_return(FHIR::Meta.new)

      expect(resource.set_meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_type' do
    it 'returns a hash' do
      allow(resource).to receive(:identifier_code).and_return('RESOURCEID')

      expect(resource.identifier_type).to eq(identifier_type_hash)
    end
  end

  describe '#set_identifiers' do
    it 'returns the models identifier' do
      set_identifiers_hash = {
        'type' => identifier_type_hash,
        'system' => 'urn:uuid:2.16.840.1.113883.4.349',
        'value' => '123456'
      }
      allow(resource).to receive(:identifier).and_return(FHIR::Identifier.new)
      allow(resource).to receive(:identifier_value).and_return('123456')
      allow(resource).to receive(:identifier_type).and_return(identifier_type_hash)

      expect(resource.set_identifiers.to_hash).to eq(set_identifiers_hash)
    end
  end
end
