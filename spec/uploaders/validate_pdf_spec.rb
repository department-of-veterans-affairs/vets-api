# frozen_string_literal: true

require 'rails_helper'

describe ValidatePdf, uploader_helpers: true do
  class ValidatePdfTest < CarrierWave::Uploader::Base
    include ValidatePdf
  end

  def store_image
    ValidatePdfTest.new.store!(file)
  end

  context 'with a file that is not a PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

    it 'should not raise an error' do
      expect { store_image }.to_not raise_error
    end
  end

  context 'with a valid PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }

    it 'should not raise an error' do
      expect { store_image }.to_not raise_error
    end
  end

  context 'with an encrypted PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/locked-pdf.pdf', 'application/pdf') }

    it 'should raise an error' do
      expect { store_image }
        .to raise_error(CarrierWave::UploadError, 'The uploaded PDF file is encrypted and cannot be read')
    end
  end

  context 'with a corrupted PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/malformed-pdf.pdf', 'application/pdf') }

    it 'should raise an error' do
      expect { store_image }
        .to raise_error(CarrierWave::UploadError, 'The uploaded PDF file is invalid and cannot be read')
    end
  end
end
