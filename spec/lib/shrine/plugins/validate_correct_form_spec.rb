# frozen_string_literal: true

require 'rails_helper'
require 'action_dispatch/http/mime_type'
require 'shrine'
require 'shrine/plugins/validate_correct_form'

describe Shrine::Plugins::ValidateCorrectForm do
  let(:klass) do
    Class.new do
      include Shrine::Plugins::ValidateCorrectForm::AttacherMethods
      def get
        raise "shouldn't be called"
      end

      def record
        self
      end

      def warnings
        @warnings ||= []
      end
    end
  end

  let(:instance) { klass.new }

  describe '#validate_correct_form' do
    let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:attachment) do
      instance_double(Shrine::UploadedFile, download: File.open(file), mime_type: 'application/pdf')
    end

    before do
      allow(instance).to receive(:get).and_return(attachment)
      allow(MiniMagick::Tool::Convert).to receive(:new)
    end

    context 'with correct form' do
      before do
        allow_any_instance_of(RTesseract).to receive(:to_s).and_return('correct-form')
      end

      it 'does not add a warning' do
        expect { instance.validate_correct_form(form_id: 'correct-form') }.not_to(
          change { instance.warnings.count }
        )
      end
    end

    context 'with wrong form' do
      before do
        allow_any_instance_of(RTesseract).to receive(:to_s).and_return('wrong-form')
      end

      it 'adds a warning' do
        expect { instance.validate_correct_form(form_id: 'correct-form') }.to(
          change { instance.warnings.count }.from(0).to(1)
        )
      end
    end
  end

  describe '#validate_correct_form integration test' do
    let(:test_pdf) { Rails.root.join('spec', 'fixtures', 'files', 'VBA-21-686c-ARE.pdf') }
    let(:attachment) do
      instance_double(Shrine::UploadedFile, download: File.open(test_pdf), mime_type: 'application/pdf')
    end

    before do
      skip 'VBA-21-686c-ARE.pdf fixture not found' unless File.exist?(test_pdf)
      allow(instance).to receive(:get).and_return(attachment)
    end

    after do
      Rails.root.glob('tmp/*.jpg').each { |f| File.delete(f) }
    end

    context 'when PDF contains the correct form ID' do
      it 'successfully extracts form ID via OCR and does not add warning' do
        expect { instance.validate_correct_form(form_id: '21-686c') }.not_to(
          change { instance.warnings.count }
        )
      end
    end
  end
end
