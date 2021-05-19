# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Composer do
  subject { described_class }

  describe '.synthesize' do
    it 'is an instance of composer' do
      expect(subject.synthesize).to be_an_instance_of(described_class)
    end
  end

  describe 'included modules' do
    it 'includes {Prawn::View}' do
      expect(subject.ancestors).to include(Prawn::View)
    end
  end

  describe 'attributes' do
    it 'responds to opts' do
      expect(subject.synthesize({}).respond_to?(:opts)).to eq(true)
    end

    it 'responds to properties' do
      expect(subject.synthesize({}).respond_to?(:properties)).to eq(true)
    end
  end

  describe '#document' do
    let(:properties) { described_class.synthesize.properties }

    it 'returns an instance of {Prawn::Document}' do
      expect(subject.synthesize.document).to be_an_instance_of(Prawn::Document)
    end

    it 'contains properties' do
      expect(subject.synthesize.document.state.store.info.data).to eq(properties.info)
    end

    it 'receives the correct arguments' do
      args = {
        page_size: properties.page_size,
        page_layout: properties.page_layout,
        margin: properties.margin,
        info: properties.info
      }

      expect(Prawn::Document).to receive(:new).with(args)

      subject.synthesize.document
    end
  end
end
