# frozen_string_literal: true

require 'rails_helper'

describe HealthQuest::QuestionnaireManager::PdfGenerator::Composer do
  subject { described_class }

  describe '.synthesize' do
    before do
      allow_any_instance_of(described_class).to receive(:build_pdf).and_return(nil)
    end

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
    before do
      allow_any_instance_of(described_class).to receive(:build_pdf).and_return(nil)
    end

    it 'responds to opts' do
      expect(subject.synthesize({}).respond_to?(:opts)).to be(true)
    end

    it 'responds to properties' do
      expect(subject.synthesize({}).respond_to?(:properties)).to be(true)
    end
  end

  describe '#document' do
    let(:properties) { described_class.synthesize.properties }

    before do
      allow_any_instance_of(described_class).to receive(:build_pdf).and_return(nil)
    end

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

  describe '#set_font' do
    before do
      allow_any_instance_of(described_class).to receive(:build_pdf).and_return(nil)
    end

    it 'sets the font' do
      expect(subject.synthesize.set_font).to be_a(Prawn::Fonts::TTF)
    end
  end

  describe '#build_pdf' do
    context 'fonts' do
      before do
        allow_any_instance_of(Prawn::Document).to receive(:repeat).and_return(nil)
        allow_any_instance_of(Prawn::Document).to receive(:bounding_box).and_return(nil)
        allow_any_instance_of(described_class).to receive(:set_font).and_return(nil)
      end

      it 'sets the font' do
        expect_any_instance_of(described_class).to receive(:set_font).once

        subject.synthesize({}).to_s
      end
    end

    context 'layout components' do
      before do
        allow_any_instance_of(described_class).to receive(:set_font).and_return(nil)
      end

      it 'builds the components in order' do
        expect_any_instance_of(HealthQuest::QuestionnaireManager::PdfGenerator::Header).to receive(:draw).once
        expect_any_instance_of(HealthQuest::QuestionnaireManager::PdfGenerator::Footer).to receive(:draw).once
        expect_any_instance_of(HealthQuest::QuestionnaireManager::PdfGenerator::AppointmentInfo).to receive(:draw).once
        expect_any_instance_of(HealthQuest::QuestionnaireManager::PdfGenerator::Demographics).to receive(:draw).once
        expect_any_instance_of(HealthQuest::QuestionnaireManager::PdfGenerator::QuestionnaireResponseInfo)
          .to receive(:draw).once

        subject.synthesize({}).to_s
      end
    end
  end
end
