# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::Efolder::Service do
  let(:pa) { build_stubbed(:pension_burial) } # a claim with persistent_attachments
  let(:metadata) {{
        'first_name' => 'Pat',
        'last_name' => 'Doe',
        'file_number' => '123-44-5678',
        'receive_date' => Time.now.strftime('%Y-%m-%d %H:%M:%S'),
        'guid' => pa.saved_claim.guid,
        'zip_code' => '78504',
        'source' => 'va.gov',
        'doc_type' => pa.saved_claim.form_id
  }}
  let(:file) { fixture_file_upload(
    "#{::Rails.root}/spec/fixtures/pension/attachment.pdf", 'application/pdf')
  }

  before do
    allow(pa).to receive('file').and_return(file)
  end

  describe '#initialize' do
    context 'with file type of ClaimDocumentation::Uploader::UploadedFile' do
      before { allow(pa.file).to receive('class').and_return('ClaimDocumentation::Uploader::UploadedFile') }
      it 'initializes' do
        upload = described_class.new(pa.file, metadata)
        uploaded_file = upload.instance_variable_get(:@file)
        filename = upload.instance_variable_get(:@filename)

        expect(uploaded_file.path).to eq(pa.file.path)
        expect(filename).to match('^([a-z0-9]+-){5}attachment.pdf')
      end
    end

    context 'with PORO file' do
      before { allow(pa.file).to receive('class').and_return('File') }
      it 'initializes' do
        upload = described_class.new(file, metadata)
        uploaded_file = upload.instance_variable_get(:@file)
        filename = upload.instance_variable_get(:@filename)
        expect(uploaded_file.path).to eq(pa.file.path)
        expect(filename).to match("^([a-z0-9]+-){5}#{File.basename(file.tempfile)}")
      end
    end
  end
end
