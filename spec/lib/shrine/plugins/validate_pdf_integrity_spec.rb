# frozen_string_literal: true

require 'rails_helper'
require 'action_dispatch/http/mime_type'
require 'shrine'
require 'shrine/plugins/validate_pdf_integrity'

describe Shrine::Plugins::ValidatePdfIntegrity do
  let(:klass) do
    Class.new do
      include Shrine::Plugins::ValidatePdfIntegrity::AttacherMethods

      def get
        raise "shouldn't be called"
      end

      def errors
        @errors ||= []
      end
    end
  end

  let(:instance) { klass.new }

  describe '#validate_pdf_integrity' do
    context 'when file is not a PDF' do
      let(:attachment) do
        instance_double(Shrine::UploadedFile, mime_type: 'image/jpeg')
      end

      before { allow(instance).to receive(:get).and_return(attachment) }

      it 'skips validation' do
        expect { instance.validate_pdf_integrity }.not_to(
          change { instance.errors.count }
        )
      end
    end

    context 'when PDF is valid with pages' do
      let(:file) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }
      let(:attachment) do
        instance_double(Shrine::UploadedFile, download: File.open(file), mime_type: 'application/pdf')
      end

      before do
        allow(instance).to receive(:get).and_return(attachment)
      end

      it 'does not add an error' do
        expect { instance.validate_pdf_integrity }.not_to(
          change { instance.errors.count }
        )
      end
    end

    context 'when PDF has zero pages' do
      let(:zero_page_pdf) do
        file = Tempfile.new(['zero_pages', '.pdf'])
        file.write(<<~PDF)
          %PDF-1.4
          1 0 obj
          << /Type /Catalog /Pages 2 0 R >>
          endobj
          2 0 obj
          << /Type /Pages /Kids [] /Count 0 >>
          endobj
          xref
          0 3
          0000000000 65535 f#{' '}
          0000000009 00000 n#{' '}
          0000000058 00000 n#{' '}
          trailer
          << /Size 3 /Root 1 0 R >>
          startxref
          109
          %%EOF
        PDF
        file.rewind
        file
      end

      let(:attachment) do
        instance_double(Shrine::UploadedFile, download: zero_page_pdf, mime_type: 'application/pdf')
      end

      before { allow(instance).to receive(:get).and_return(attachment) }

      after do
        zero_page_pdf.close
        zero_page_pdf.unlink
      end

      it 'adds an error' do
        expect { instance.validate_pdf_integrity }.to(
          change { instance.errors.count }.from(0).to(1)
        )
      end

      it 'includes a readable error message' do
        instance.validate_pdf_integrity
        expect(instance.errors
        .first).to eq('We couldn’t open your PDF. Please save it and try uploading it again.')
      end
    end

    context 'when PDF is malformed' do
      let(:malformed_pdf) do
        file = Tempfile.new(['malformed', '.pdf'])
        file.write('%PDF-1.4 this is not valid pdf content')
        file.rewind
        file
      end

      let(:attachment) do
        instance_double(Shrine::UploadedFile, download: malformed_pdf, mime_type: 'application/pdf')
      end

      before { allow(instance).to receive(:get).and_return(attachment) }

      after do
        malformed_pdf.close
        malformed_pdf.unlink
      end

      it 'adds an error' do
        expect { instance.validate_pdf_integrity }.to(
          change { instance.errors.count }.from(0).to(1)
        )
      end

      it 'includes a readable error message' do
        instance.validate_pdf_integrity
        expect(instance.errors).to include('We couldn’t upload your PDF because the file is corrupted')
      end

      it 'logs a warning' do
        expect(Rails.logger).to receive(:warn).with(/validate_pdf_integrity:/)
        instance.validate_pdf_integrity
      end
    end

    context 'when PDF has completely invalid content' do
      let(:corrupt_pdf) do
        file = Tempfile.new(['corrupt', '.pdf'])
        file.write('This is not a PDF at all, just plain text')
        file.rewind
        file
      end

      let(:attachment) do
        instance_double(Shrine::UploadedFile, download: corrupt_pdf, mime_type: 'application/pdf')
      end

      before { allow(instance).to receive(:get).and_return(attachment) }

      after do
        corrupt_pdf.close
        corrupt_pdf.unlink
      end

      it 'adds an error' do
        expect { instance.validate_pdf_integrity }.to(
          change { instance.errors.count }.from(0).to(1)
        )
      end

      it 'includes a readable error message' do
        instance.validate_pdf_integrity
        expect(instance.errors).to include('We couldn’t upload your PDF because the file is corrupted')
      end
    end
  end
end
