# frozen_string_literal: true

require 'rails_helper'

describe EVSSClaimDocumentUploaderBase, :uploader_helpers do
  before do
    allow_any_instance_of(described_class).to receive(:max_file_size_non_pdf).and_return(100)
  end

  def store_image
    EVSSClaimDocumentUploaderBase.new.store!(file)
  end

  context 'with a too large file that is not a PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/va.gif', 'image/gif') }

    it 'raises an error' do
      expect { store_image }.to raise_error CarrierWave::IntegrityError
    end
  end

  context 'with a valid PDF' do
    let(:file) { Rack::Test::UploadedFile.new('spec/fixtures/files/doctors-note.pdf', 'application/pdf') }

    it 'does not raise an error' do
      expect { store_image }.not_to raise_error
    end
  end
end
