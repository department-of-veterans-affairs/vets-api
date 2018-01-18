# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    let(:file_path) { Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.pdf') }

    it 'should upload a file' do
      VCR.use_cassette('pension_burial/upload', match_requests_on: [:body]) do
        response = described_class.new.upload(
          { form_id: '99-9999EZ', code: 'V-TESTTEST', guid: '123', original_filename: 'doctors-note.pdf' },
          StringIO.new(File.read(file_path)),
          'application/pdf'
        )
        body = response.body

        expect(body['fileSize']).to eq(10_548)
        expect(body['metaSize']).to eq(95)
        expect(response.status).to eq(200)
      end
    end
  end
end
