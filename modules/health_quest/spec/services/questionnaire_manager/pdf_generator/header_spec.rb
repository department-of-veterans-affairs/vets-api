# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Header do
  subject { described_class }

  describe '.build' do
    it 'is an instance of Header' do
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
    let(:qr) do
      double(
        'QuestionnaireResponse',
        questionnaire_response_data: { 'questionnaire' => { 'title' => 'foo' } }
      )
    end
    let(:org) do
      double('Org', resource: double('Resource', name: 'Bar'))
    end
    let(:composer) { HealthQuest::QuestionnaireManager::PdfGenerator::Composer }

    before do
      allow_any_instance_of(composer).to receive(:build_pdf).and_return('')
    end

    it 'uses a bounding box' do
      expect_any_instance_of(Prawn::Document).to receive(:bounding_box).once

      subject.build(opts: { questionnaire_response: qr, org: }, composer: composer.synthesize).draw.to_s
    end

    it 'receives a block' do
      expect_any_instance_of(Prawn::Document).to receive(:bounding_box).and_yield

      subject.build(opts: { questionnaire_response: qr, org: }, composer: composer.synthesize).draw.to_s
    end
  end

  describe '#qr_data' do
    let(:qr) do
      double(
        'QuestionnaireResponse',
        questionnaire_response_data: {
          'item' => [{ 'answer' => [{ 'valueString' => 'bar' }], 'text' => 'foo' }]
        }
      )
    end

    it 'returns qr snapshot data' do
      data = { 'item' => [{ 'answer' => [{ 'valueString' => 'bar' }], 'text' => 'foo' }] }

      expect(subject.build(opts: { questionnaire_response: qr }).qr_data).to eq(data)
    end
  end

  describe '#org_name' do
    let(:org) do
      double('Org', resource: double('Resource', name: 'Bar'))
    end

    it 'returns the org name' do
      expect(subject.build(opts: { org: }).org_name).to eq('Bar')
    end
  end

  describe '#today' do
    it 'returns today\'s date' do
      date = DateTime.now.to_date.strftime('%m/%d/%Y')

      expect(subject.build.today).to eq(date)
    end
  end
end
