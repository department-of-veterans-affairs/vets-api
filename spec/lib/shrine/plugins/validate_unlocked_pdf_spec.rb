# frozen_string_literal: true

require 'rails_helper'
require 'shrine/plugins/validate_unlocked_pdf'

describe Shrine::Plugins::ValidateUnlockedPdf do
  describe '#validate_unlocked_pdf' do
    let(:good_pdf) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
    let(:locked_pdf) { Rails.root.join('spec', 'fixtures', 'files', 'locked-pdf.pdf') }
    let(:malformed_pdf) { Rails.root.join('spec', 'fixtures', 'files', 'malformed-pdf.pdf') }

    let(:klass) do
      Class.new do
        include Shrine::Plugins::ValidateUnlockedPdf::AttacherMethods
        def get
          raise "shouldn't be called"
        end

        def errors
          @errors ||= []
        end
      end
    end

    let(:instance) { klass.new }

    let(:attachment) do
      instance_double(Shrine::UploadedFile, download: File.open(file), mime_type: 'application/pdf')
    end

    before do
      allow(instance).to receive(:get).and_return(attachment)
    end

    context 'with a valid pdf' do
      let(:file) { good_pdf }

      it 'does not add any errors' do
        expect { instance.validate_unlocked_pdf }.not_to change { instance.errors.count }
      end
    end

    context 'with a locked pdf' do
      let(:file) { locked_pdf }

      it 'adds an error' do
        expect { instance.validate_unlocked_pdf }.to change { instance.errors.count }.from(0).to(1)
        expect(instance.errors.first).to eq I18n.t('errors.messages.uploads.pdf.locked')
      end
    end

    context 'with a malformed or invalid pdf' do
      let(:file) { malformed_pdf }

      it 'adds an error' do
        expect { instance.validate_unlocked_pdf }.to change { instance.errors.count }.from(0).to(1)
        expect(instance.errors.first).to eq I18n.t('errors.messages.uploads.pdf.invalid')
      end
    end
  end
end
