# frozen_string_literal: true

require 'rails_helper'

RSpec.describe IvcChampva::TempfileHelper do
  let(:form_id) { 'vha_10_7959a' }
  let(:file_content) { 'test file content' }

  context 'when attachment.file responds to original_filename' do
    let(:mock_file) do
      double('UploadedFile',
             original_filename: 'some_file.gif',
             rewind: true)
    end

    let(:attachment) do
      instance_double(PersistentAttachments::MilitaryRecords, file: mock_file)
    end

    before do
      allow(mock_file).to receive(:read).and_return(file_content, nil) # It's important to return nil after the content
    end

    it 'creates a tempfile with the original filename extension and random code' do
      tmpfile = described_class.tempfile_from_attachment(attachment, form_id)

      expect(tmpfile).to be_a(Tempfile)
      expect(File.basename(tmpfile.path)).to match(/^vha_10_7959a_attachment_[\w-]+\.gif$/)
      tmpfile.rewind
      expect(tmpfile.read).to eq(file_content)
      tmpfile.close
      tmpfile.unlink
    end
  end

  context 'when attachment.file does not respond to original_filename' do
    let(:mock_file) do
      double('File',
             path: '/tmp/some_other_file.png',
             rewind: true)
    end

    let(:attachment) do
      instance_double(PersistentAttachments::MilitaryRecords, file: mock_file)
    end

    before do
      allow(mock_file).to receive(:read).and_return(file_content, nil) # It's important to return nil after the content
    end

    it 'creates a tempfile with the basename extension and random code' do
      tmpfile = described_class.tempfile_from_attachment(attachment, form_id)

      expect(tmpfile).to be_a(Tempfile)
      expect(File.basename(tmpfile.path)).to match(/^vha_10_7959a_attachment_[\w-]+\.png$/)
      tmpfile.rewind
      expect(tmpfile.read).to eq(file_content)
      tmpfile.close
      tmpfile.unlink
    end
  end
end
