# frozen_string_literal: true

require 'rails_helper'
require 'form526_backup_submission/utilities/convert_to_pdf'

RSpec.describe Form526BackupSubmission::Utilities::ConvertToPdf do
  subject { described_class }

  let(:txt_file) { 'spec/fixtures/files/buddy_statement.txt' }
  let(:pdf_file) { 'spec/fixtures/files/doctors-note.pdf' }
  let(:json_file) { 'spec/fixtures/va_profile/items_and_permissions.json' }

  describe 'image files' do
    {
      jpg: 'spec/fixtures/files/doctors-note-actual-jpg.jpg',
      png: 'spec/fixtures/files/doctors-note.png',
      gif: 'spec/fixtures/files/doctors-note.png',
      bmp: 'spec/fixtures/files/doctors-note.bmp'
    }.each do |img_type, file_path|
      it "can convert the supported image type \"#{img_type}\" to PDF" do
        converted = described_class.new(file_path)
        expect(converted.original_file).to eq(file_path)
        expect(converted.original_filename).to eq(File.basename(file_path))
        expect(converted.converted_filename).not_to be(nil)
        expect(File.extname(converted.converted_filename).downcase).to eq('.pdf')
      end
    end
  end

  describe 'text files' do
    # This test case is broken out from the above because it is not an image and goes
    # down a different code path. Want to keep them seperate.
    it 'can convert supported txt file to PDF' do
      converted = described_class.new(txt_file)
      expect(converted.original_file).to eq(txt_file)
      expect(converted.original_filename).to eq(File.basename(txt_file))
      expect(converted.converted_filename).not_to be(nil)
      expect(File.extname(converted.converted_filename).downcase).to eq('.pdf')
    end
  end

  describe 'expected errors' do
    it 'errors when trying to convert a PDF file to a PDF' do
      expect do
        described_class.new(pdf_file)
      end.to raise_error(RuntimeError, 'Unsupported file type (.pdf), cannot convert to PDF.')
    end

    it 'errors when trying to convert a non-supported file to a PDF' do
      expect do
        described_class.new(json_file)
      end.to raise_error(RuntimeError, 'Unsupported file type (.json), cannot convert to PDF.')
    end
  end
end
