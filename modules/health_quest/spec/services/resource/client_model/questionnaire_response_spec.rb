# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::Resource::ClientModel::QuestionnaireResponse do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
  let(:data) do
    {
      appointment: {
        id: 'abc123'
      },
      questionnaire: {
        id: subject::DEFAULT_QUESTIONNAIRE_ID,
        title: subject::DEFAULT_QUESTIONNAIRE_TITLE
      },
      item: []
    }
  end
  let(:identifier_hash) do
    {
      'type' => {
        'coding' => [{
          'system' => subject::CODING_SYSTEM,
          'code' => 'QuestionnaireResponseID',
          'userSelected' => false
        }]
      },
      'system' => subject::SYSTEM_ID,
      'value' => subject::DEFAULT_QUESTIONNAIRE_ID
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
    it 'returns an instance of MapQuery' do
      expect(subject.manufacture(data, user)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has attributes' do
      %i[user model identifier meta data source_reference subject_reference].each do |attribute|
        expect(subject.manufacture(data, user).respond_to?(attribute)).to be(true)
      end
    end

    it 'has an instance of a FHIR::QuestionnaireResponse' do
      expect(subject.manufacture(data, user).model).to be_an_instance_of(FHIR::QuestionnaireResponse)
    end

    it 'has an instance of a User' do
      expect(subject.manufacture(data, User.new).user).to be_an_instance_of(User)
    end

    it 'has an instance of a data hash' do
      expect(subject.manufacture(data, user).data).to be_an_instance_of(Hash)
    end

    it 'has an identifier' do
      expect(subject.manufacture(data, user).identifier).to be_an_instance_of(FHIR::Identifier)
    end

    it 'has a source_reference' do
      expect(subject.manufacture(data, user).source_reference).to be_an_instance_of(FHIR::Reference)
    end

    it 'has a codeable_concept' do
      expect(subject.manufacture(data, user).codeable_concept).to be_an_instance_of(FHIR::CodeableConcept)
    end

    it 'has a subject_reference' do
      expect(subject.manufacture(data, user).subject_reference).to be_an_instance_of(FHIR::Reference)
    end

    it 'has an instance of a FHIR::Meta' do
      expect(subject.manufacture(data, user).meta).to be_an_instance_of(FHIR::Meta)
    end

    it 'has a narrative' do
      expect(subject.manufacture(data, user).narrative).to be_an_instance_of(FHIR::Narrative)
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
      coding.code = 'QuestionnaireResponseID'
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
    it 'has an identifier hash' do
      expect(subject.manufacture(data, user).prepare.identifier.to_hash).to eq(identifier_hash)
    end

    it 'has a meta hash' do
      expect(subject.manufacture(data, user).prepare.meta.to_hash).to eq(meta_hash)
    end

    it 'has a text hash' do
      narrative = FHIR::Narrative.new
      narrative.status = 'generated'
      narrative.div = '<div><h1>Pre-Visit Questionnaire</h1></div>'

      expect(subject.manufacture(data, user).prepare.text).to eq(narrative)
    end

    it 'has a completed status' do
      expect(subject.manufacture(data, user).prepare.status).to eq(subject::COMPLETED_STATUS)
    end

    it 'has an authored date' do
      expect(subject.manufacture(data, user).prepare.authored).to include(DateTime.now.in_time_zone.to_date.to_s)
    end

    it 'has a subject' do
      url = Settings.hqva_mobile.lighthouse.url
      health_api_path = Settings.hqva_mobile.lighthouse.health_api_path
      appt_reference = "#{url}#{health_api_path}/Appointment/abc123"

      expect(subject.manufacture(data, user).prepare.subject.reference).to eq(appt_reference)
    end

    it 'has a source' do
      url = Settings.hqva_mobile.lighthouse.url
      health_api_path = Settings.hqva_mobile.lighthouse.health_api_path
      patient_reference = "#{url}#{health_api_path}/Patient/1008596379V859838"

      expect(subject.manufacture(data, user).prepare.source.reference).to eq(patient_reference)
    end

    it 'has a questionnaire' do
      expect(subject.manufacture(data, user).prepare.questionnaire)
        .to eq("Questionnaire/#{subject::DEFAULT_QUESTIONNAIRE_ID}")
    end

    it 'has a group' do
      expect(subject.manufacture(data, user).prepare.item).to eq(data[:item])
    end
  end

  describe '#identifier_value' do
    it 'returns the resource identifier value' do
      expect(subject.manufacture(data, user).identifier_value).to eq('1776c749-91b8-4f33-bece-a5a72f3bb09b')
    end
  end

  describe '#identifier_code' do
    it 'returns the patient resource identifier' do
      expect(subject.manufacture(data, user).identifier_code).to eq('QuestionnaireResponseID')
    end
  end
end
