# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Properties do
  subject { described_class }

  describe '.build' do
    it 'is an instance of properties' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe '#info' do
    let(:properties_info_hash) do
      {
        Lang: 'en-us',
        Title: 'Primary Care Questionnaire',
        Author: 'Department of Veterans Affairs',
        Subject: 'Primary Care Questionnaire',
        Keywords: 'health questionnaires pre-visit',
        Creator: 'va.gov',
        Producer: 'va.gov',
        CreationDate: Time.zone.today.to_s
      }
    end

    it 'returns the properties info hash' do
      expect(subject.build.info).to eq(properties_info_hash)
    end
  end

  describe '#title' do
    it 'returns `Primary Care Questionnaire`' do
      expect(subject.build.title).to eq('Primary Care Questionnaire')
    end
  end

  describe '#language' do
    it 'returns `en-us`' do
      expect(subject.build.language).to eq('en-us')
    end
  end

  describe '#author' do
    it 'returns `Department of Veterans Affairs`' do
      expect(subject.build.author).to eq('Department of Veterans Affairs')
    end
  end

  describe '#subject' do
    it 'returns `Primary Care Questionnaire`' do
      expect(subject.build.subject).to eq('Primary Care Questionnaire')
    end
  end

  describe '#keywords' do
    it 'returns `health questionnaires pre-visit`' do
      expect(subject.build.keywords).to eq('health questionnaires pre-visit')
    end
  end

  describe '#creator' do
    it 'returns `va.gov`' do
      expect(subject.build.creator).to eq('va.gov')
    end
  end

  describe '#producer' do
    it 'returns `va.gov`' do
      expect(subject.build.producer).to eq('va.gov')
    end
  end

  describe '#creation_date' do
    it 'returns the date of creation' do
      expect(subject.build.creation_date).to eq(Time.zone.today.to_s)
    end
  end

  describe '#page_size' do
    it 'returns `A4`' do
      expect(subject.build.page_size).to eq('A4')
    end
  end

  describe '#page_layout' do
    it 'returns `:portrait`' do
      expect(subject.build.page_layout).to eq(:portrait)
    end
  end

  describe '#margin' do
    it 'returns `0`' do
      expect(subject.build.margin).to eq(0)
    end
  end
end
