# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/validate_correct_form'

describe Shrine::Plugins::ValidateCorrectForm do
  describe '#validate_correct_form' do
    let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }

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
          change do
            instance.warnings.count
          end
        )
      end
    end

    context 'with wrong form' do
      before do
        allow_any_instance_of(RTesseract).to receive(:to_s).and_return('wrong-form')
      end

      it 'adds a warning' do
        expect { instance.validate_correct_form(form_id: 'correct-form') }.to(
          change do
            instance.warnings.count
          end.from(0).to(1)
        )
      end
    end
  end
end
