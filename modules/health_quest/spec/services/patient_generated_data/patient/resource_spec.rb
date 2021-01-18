# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::Patient::Resource do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
  let(:identifier_hash) do
    {
      'type' => { coding: [{ system: subject::CODING_SYSTEM, code: 'ICN', userSelected: false }] },
      'system' => subject::SYSTEM_ID,
      'value' => user.icn
    }
  end
  let(:meta_hash) do
    {
      'tag' => [{ system: subject::META_SYSTEM, code: subject::META_CODE, display: subject::META_DISPLAY }]
    }
  end

  describe 'included modules' do
    it 'includes PatientGeneratedData::Common::IdentityMetaInfo' do
      expect(subject.ancestors).to include(HealthQuest::PatientGeneratedData::Common::IdentityMetaInfo)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of MapQuery' do
      expect(subject.manufacture(user)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has attributes' do
      %i[model identifier meta user].each do |attribute|
        expect(subject.manufacture(user).respond_to?(attribute)).to eq(true)
      end
    end

    it 'has an an instance of a FHIR::DSTU2::Patient' do
      expect(subject.manufacture(user).model).to be_an_instance_of(FHIR::DSTU2::Patient)
    end

    it 'has an an instance of a User' do
      expect(subject.manufacture(User.new).user).to be_an_instance_of(User)
    end

    it 'has an an instance of a FHIR::DSTU2::Identifier' do
      expect(subject.manufacture(user).identifier).to be_an_instance_of(FHIR::DSTU2::Identifier)
    end

    it 'has an an instance of a FHIR::DSTU2::Meta' do
      expect(subject.manufacture(user).meta).to be_an_instance_of(FHIR::DSTU2::Meta)
    end
  end

  describe '#name' do
    it 'returns a name array' do
      expect(subject.manufacture(user).name).to eq([{ use: 'official', family: ['Smith'], given: ['Bob'] }])
    end
  end

  describe '#set_meta' do
    it 'returns a formatted hash' do
      expect(subject.manufacture(user).set_meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_type' do
    it 'returns a hash' do
      identifier_type_hash = {
        coding: [{ system: subject::CODING_SYSTEM, code: 'ICN', userSelected: false }]
      }

      expect(subject.manufacture(user).identifier_type).to eq(identifier_type_hash)
    end
  end

  describe '#set_identifiers' do
    it 'returns a formatted hash' do
      expect(subject.manufacture(user).set_identifiers.to_hash).to eq(identifier_hash)
    end
  end

  describe '#prepare' do
    it 'has a name array' do
      expect(subject.manufacture(user).prepare.name).to eq([{ use: 'official', family: ['Smith'], given: ['Bob'] }])
    end

    it 'has an identifier hash' do
      expect(subject.manufacture(user).prepare.identifier.to_hash).to eq(identifier_hash)
    end

    it 'has a meta hash' do
      expect(subject.manufacture(user).prepare.meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_value' do
    it 'returns the resource identifier value' do
      expect(subject.manufacture(user).identifier_value).to eq(user.icn)
    end
  end

  describe '#identifier_code' do
    it 'returns the patient resource identifier' do
      expect(subject.manufacture(user).identifier_code).to eq('ICN')
    end
  end
end
