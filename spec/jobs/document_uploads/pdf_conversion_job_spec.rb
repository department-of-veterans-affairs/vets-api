# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DocumentUploads::PdfConversionJob do
  describe '#perform' do


    context 'with an image' do
      before(:all) do
        @file_path = Rails.root.join('spec', 'fixtures', 'files', 'pdf_conversion.jpg')
        @file_path_converted = Rails.root.join('spec', 'fixtures', 'files', 'pdf_conversion.jpg.pdf')
        create_jpg(@file_path)
      end

      it 'should convert the image to a PDF' do
        subject.perform(@file_path)
        expect(@file_path_converted.exist?).to be_truthy
        expect(IO.read(@file_path_converted, 10)).to match(/%PDF-\d.\d/)
      end

      context 'when an error occurs' do
        it 'should log and reraise the error' do
          allow_any_instance_of(MiniMagick::Tool::Convert).to receive(:command).and_raise(MiniMagick::Error)
          expect(Rails.logger).to receive(:error).once.with('Failed to convert image to pdf: MiniMagick::Error')
          expect do
            subject.perform(@file_path)
          end.to raise_error(MiniMagick::Error)
        end
      end

      after(:all) do
        [@file_path, @file_path_converted].map do |f|
          File.delete f if File.exist? f
        end
      end
    end

    context 'with a word doc' do
      before(:all) do
        @file_path = Rails.root.join('spec', 'fixtures', 'files', 'word_conversion.docx')
        @file_path_converted = Rails.root.join('spec', 'fixtures', 'files', 'word_conversion.docx.pdf')
      end

      it 'should convert the document to a PDF' do
        subject.perform(@file_path)
        expect(@file_path_converted.exist?).to be_truthy
        expect(IO.read(@file_path_converted, 10)).to match(/%PDF-\d.\d/)
      end

      after(:all) do
        File.delete @file_path_converted if File.exist? @file_path_converted
      end
    end
  end
end
