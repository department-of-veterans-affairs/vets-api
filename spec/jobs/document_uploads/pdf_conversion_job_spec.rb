# frozen_string_literal: true
require 'rails_helper'

RSpec.describe DocumentUploads::PdfConversionJob do
  describe '#perform' do
    before(:all) do
      @file_path = Rails.root.join('spec/fixtures/files/pdf_conversion.jpg')
      @file_path_converted = Rails.root.join('spec/fixtures/files/pdf_conversion.jpg.pdf')
      MiniMagick::Tool::Convert.new do |convert|
        convert.size '1024x768'
        convert.gravity 'center'
        convert.xc 'white'
        convert << @file_path
      end
    end

    context 'with an image' do
      it 'should convert the image to a PDF' do
        subject.perform(@file_path)
        expect(@file_path_converted.exist?).to be_truthy
        expect(IO.read(@file_path_converted, 10)).to match(/%PDF-\d.\d/)
      end
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
end
