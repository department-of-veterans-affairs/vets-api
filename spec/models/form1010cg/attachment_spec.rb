# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Form1010cg::Attachment, type: :model do
  let(:guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
  let(:subject) { described_class.new(guid:) }
  let(:vcr_options) do
    {
      record: :none,
      allow_unused_http_interactions: false,
      match_requests_on: %i[method host body]
    }
  end

  it 'is a FormAttachment model' do
    expect(described_class.ancestors).to include(FormAttachment)
  end

  it 'has an uploader configured' do
    expect(described_class::ATTACHMENT_UPLOADER_CLASS).to eq(Form1010cg::PoaUploader)
  end

  describe '#to_local_file' do
    let(:file_fixture_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg') }
    let(:expected_local_file_path) { "tmp/#{guid}_doctors-note.jpg" }
    let(:remote_file_content) { nil }

    before do
      VCR.use_cassette("s3/object/put/#{guid}/doctors-note_jpg", vcr_options) do
        subject.set_file_data!(
          Rack::Test::UploadedFile.new(file_fixture_path, 'image/jpg')
        )
      end
    end

    after do
      FileUtils.rm_f(expected_local_file_path)
    end

    it 'makes a local copy of the file' do
      VCR.use_cassette("s3/object/get/#{guid}/doctors-note_jpg", vcr_options) do
        expect(subject.to_local_file).to eq(expected_local_file_path)
        expect(
          FileUtils.compare_file(expected_local_file_path, file_fixture_path)
        ).to be(true)
      end
    end
  end
end
