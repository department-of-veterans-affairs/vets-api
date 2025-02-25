# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Resource::ClientModel::Patient do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
  let(:data) { {} }
  let(:identifier_hash) do
    {
      'type' => { 'coding' => [{ 'system' => subject::CODING_SYSTEM, 'code' => 'ICN', 'userSelected' => false }] },
      'system' => subject::SYSTEM_ID,
      'value' => user.icn
    }
  end
  let(:meta_hash) do
    {
      'tag' => [{
        'system' => subject::META_SYSTEM,
        'code' => subject::META_CODE,
        'display' => subject::META_DISPLAY
      }]
    }
  end

  describe 'included modules' do
    it 'includes Shared::IdentityMetaInfo' do
      expect(subject.ancestors).to include(HealthQuest::Shared::IdentityMetaInfo)
    end
  end

  describe '.manufacture' do
    it 'returns an instance of subject' do
      expect(subject.manufacture(data, user)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has attributes' do
      %i[model identifier meta user].each do |attribute|
        expect(subject.manufacture(data, user).respond_to?(attribute)).to be(true)
      end
    end

    it 'has an an instance of a FHIR::Patient' do
      expect(subject.manufacture(data, user).model).to be_an_instance_of(FHIR::Patient)
    end

    it 'has an an instance of a User' do
      expect(subject.manufacture(data, User.new).user).to be_an_instance_of(User)
    end

    it 'has an an instance of a FHIR::Identifier' do
      expect(subject.manufacture(data, user).identifier).to be_an_instance_of(FHIR::Identifier)
    end

    it 'has an an instance of a FHIR::Meta' do
      expect(subject.manufacture(data, user).meta).to be_an_instance_of(FHIR::Meta)
    end
  end

  describe '#name' do
    it 'returns a name array' do
      expect(subject.manufacture(data, user).name).to eq([{ use: 'official', family: ['Smith'], given: ['Bob'] }])
    end
  end

  describe '#set_meta' do
    it 'returns a formatted hash' do
      expect(subject.manufacture(data, user).set_meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_type' do
    it 'returns a hash' do
      coding = FHIR::Coding.new
      coding.system = subject::CODING_SYSTEM
      coding.code = 'ICN'
      coding.userSelected = false
      codeable_concept = FHIR::CodeableConcept.new
      codeable_concept.coding = [coding]

      expect(subject.manufacture(data, user).identifier_type).to eq(codeable_concept)
    end
  end

  describe '#set_identifiers' do
    it 'returns a formatted hash' do
      expect(subject.manufacture(data, user).set_identifiers.to_hash).to eq(identifier_hash)
    end
  end

  describe '#prepare' do
    it 'has a name array' do
      expect(subject.manufacture(data, user).prepare.name)
        .to eq([{ use: 'official', family: ['Smith'], given: ['Bob'] }])
    end

    it 'has an identifier hash' do
      expect(subject.manufacture(data, user).prepare.identifier.to_hash).to eq(identifier_hash)
    end

    it 'has a meta hash' do
      expect(subject.manufacture(data, user).prepare.meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_value' do
    it 'returns the resource identifier value' do
      expect(subject.manufacture(data, user).identifier_value).to eq(user.icn)
    end
  end

  describe '#identifier_code' do
    it 'returns the patient resource identifier' do
      expect(subject.manufacture(data, user).identifier_code).to eq('ICN')
    end
  end
end
