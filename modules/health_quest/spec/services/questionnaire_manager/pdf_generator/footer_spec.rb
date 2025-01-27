# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Footer do
  subject { described_class }

  let(:qr) do
    double(
      'QuestionnaireResponse',
      user_demographics_data: {
        'date_of_birth' => '05-05-1955',
        'first_name' => 'Foo',
        'last_name' => 'Bar'
      }
    )
  end
  let(:composer) { HealthQuest::QuestionnaireManager::PdfGenerator::Composer }

  before do
    allow_any_instance_of(composer).to receive(:build_pdf).and_return('')
  end

  describe '.build' do
    it 'is an instance of Footer' do
      expect(subject.build).to be_an_instance_of(described_class)
    end
  end

  describe 'attributes' do
    it 'responds to opts' do
      expect(subject.build.respond_to?(:opts)).to be(true)
    end

    it 'responds to composer' do
      expect(subject.build.respond_to?(:composer)).to be(true)
    end
  end

  describe '#draw' do
    before do
      allow_any_instance_of(described_class).to receive(:footer_text).and_return('')
    end

    it 'uses a bounding box' do
      expect_any_instance_of(Prawn::Document).to receive(:bounding_box).once

      subject.build(opts: {}, composer: composer.synthesize).draw.to_s
    end

    it 'receives a block' do
      expect_any_instance_of(Prawn::Document).to receive(:bounding_box).and_yield

      subject.build(opts: {}, composer: composer.synthesize).draw.to_s
    end
  end

  describe '#footer_text' do
    it 'has a footer text' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).footer_text)
        .to eq('Foo Bar | Date of birth: 05/05/1955')
    end
  end

  describe '#full_name' do
    it 'has a full_name' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).full_name)
        .to eq('Foo Bar')
    end
  end

  describe '#date_of_birth' do
    it 'has a date_of_birth' do
      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).date_of_birth)
        .to eq('05/05/1955')
    end
  end

  describe '#user_data' do
    it 'returns user_data' do
      data = { 'date_of_birth' => '05-05-1955', 'first_name' => 'Foo', 'last_name' => 'Bar' }

      expect(subject.build(opts: { questionnaire_response: qr }, composer: composer.synthesize).user_data)
        .to eq(data)
    end
  end
end
