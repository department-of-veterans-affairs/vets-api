# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::PatientGeneratedData::QuestionnaireResponse::Resource do
  subject { described_class }

  let(:user) { double('User', icn: '1008596379V859838', first_name: 'Bob', last_name: 'Smith') }
  let(:data) do
    {
      appointment_id: 'abc123',
      questionnaire_response: {},
      questionnaire_id: subject::DEFAULT_QUESTIONNAIRE_ID
    }
  end
  let(:identifier_hash) do
    {
      'type' => { coding: [{ system: subject::CODING_SYSTEM, code: 'QuestionnaireResponseID', userSelected: false }] },
      'system' => subject::SYSTEM_ID,
      'value' => subject::DEFAULT_QUESTIONNAIRE_ID
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
      expect(subject.manufacture(data, user)).to be_an_instance_of(subject)
    end
  end

  describe 'object initialization' do
    it 'has attributes' do
      %i[user model identifier meta data author_reference questionnaire_reference].each do |attribute|
        expect(subject.manufacture(data, user).respond_to?(attribute)).to eq(true)
      end
    end

    it 'has an an instance of a FHIR::DSTU2::QuestionnaireResponse' do
      expect(subject.manufacture(data, user).model).to be_an_instance_of(FHIR::DSTU2::QuestionnaireResponse)
    end

    it 'has an an instance of a User' do
      expect(subject.manufacture(data, User.new).user).to be_an_instance_of(User)
    end

    it 'has an an instance of a data hash' do
      expect(subject.manufacture(data, user).data).to be_an_instance_of(Hash)
    end

    it 'has an an instance of a FHIR::DSTU2::Identifier' do
      expect(subject.manufacture(data, user).identifier).to be_an_instance_of(FHIR::DSTU2::Identifier)
    end

    it 'has an an instance of a FHIR::DSTU2::Meta' do
      expect(subject.manufacture(data, user).meta).to be_an_instance_of(FHIR::DSTU2::Meta)
    end

    it 'has an an instance of a FHIR::DSTU2::Reference' do
      expect(subject.manufacture(data, user).author_reference).to be_an_instance_of(FHIR::DSTU2::Reference)
    end

    it 'has an a second instance of a FHIR::DSTU2::Reference' do
      expect(subject.manufacture(data, user).questionnaire_reference).to be_an_instance_of(FHIR::DSTU2::Reference)
    end
  end

  describe '#set_meta' do
    it 'returns a formatted hash' do
      expect(subject.manufacture(data, user).set_meta.to_hash).to eq(meta_hash)
    end
  end

  describe '#identifier_type' do
    it 'returns a hash' do
      identifier_type_hash = {
        coding: [{ system: subject::CODING_SYSTEM, code: 'QuestionnaireResponseID', userSelected: false }]
      }

      expect(subject.manufacture(data, user).identifier_type).to eq(identifier_type_hash)
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
      text_hash = {
        status: 'generated',
        div: '<div><h1>Pre-Visit Questionnaire</h1></div>'
      }

      expect(subject.manufacture(data, user).prepare.text).to eq(text_hash)
    end

    it 'has a completed status' do
      expect(subject.manufacture(data, user).prepare.status).to eq(subject::COMPLETED_STATUS)
    end

    it 'has an authored date' do
      expect(subject.manufacture(data, user).prepare.authored).to eq(Time.zone.today.to_s)
    end

    it 'has an author' do
      expect(subject.manufacture(data, user).prepare.author).to eq('Patient/1008596379V859838')
    end

    it 'has a subject' do
      subject_hash = {
        use: subject::SUBJECT_USE,
        value: "#{Settings.hqva_mobile.url}/appointments/v1/patients/1008596379V859838/Appointment/abc123"
      }

      expect(subject.manufacture(data, user).prepare.subject).to eq(subject_hash)
    end

    it 'has a questionnaire' do
      expect(subject.manufacture(data, user).prepare.questionnaire)
        .to eq("Questionnaire/#{subject::DEFAULT_QUESTIONNAIRE_ID}")
    end

    it 'has a group' do
      expect(subject.manufacture(data, user).prepare.group).to eq(data[:group])
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
