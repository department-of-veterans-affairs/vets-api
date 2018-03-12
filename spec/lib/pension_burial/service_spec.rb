# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      VCR.use_cassette('pension_burial/upload', VCR::MATCH_EVERYTHING) do
        response = described_class.new.upload(
          metadata: get_fixture('pension/metadata').to_json,
          document: Faraday::UploadIO.new(
            'spec/fixtures/pension/form.pdf',
            Mime[:pdf].to_s
          ),
          attachment1: Faraday::UploadIO.new(
            'spec/fixtures/pension/attachment.pdf',
            Mime[:pdf].to_s
          )
        )
        body = response.body

        expect(body).to eq(
          'fileSize' => 1_759_933,
          'metaSize' => 419,
          'md5' => '1I2+7z80I4jgvKenhclh5w==',
          'md5hex' => 'd48dbeef3f342388e0bca7a785c961e7'
        )
        expect(response.status).to eq(200)
      end
    end
  end
end
