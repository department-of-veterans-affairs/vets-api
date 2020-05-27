# frozen_string_literal: true

require 'rails_helper'

describe ValidatePDF, uploader_helpers: true do
  class ValidatePDFTest < CarrierWave::Uploader::Base
    include ValidatePDF
  end

  def store_image
    ValidatePDFTest.new.store!(file)
  end

  context 'with a file that is not a PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

    it 'does not raise an error' do
      expect { store_image }.not_to raise_error
    end
  end

  context 'with a valid PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }

    it 'does not raise an error' do
      expect { store_image }.not_to raise_error
    end
  end

  context 'with an encrypted PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/locked-pdf.pdf', 'application/pdf') }

    it 'raises an error' do
      expect { store_image }
        .to raise_error(CarrierWave::UploadError, 'The uploaded PDF file is encrypted and cannot be read')
    end
  end

  context 'with a corrupted PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/malformed-pdf.pdf', 'application/pdf') }

    it 'raises an error' do
      expect { store_image }
        .to raise_error(CarrierWave::UploadError, 'The uploaded PDF file is invalid and cannot be read')
    end
  end
end
