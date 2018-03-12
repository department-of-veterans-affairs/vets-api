# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      VCR.use_cassette('pension_burial/upload', VCR::MATCH_EVERYTHING) do
        response = described_class.new.upload(
          'metadata' => '{"veteranFirstName":"Test","veteranLastName":"User","fileNumber":"111223333","receiveDt":"2018-03-10 02:13:33","zipCode":"90210","uuid":"07029d0e-60b5-4bc4-8606-ef3504f2835f","source":"CSRA-V","hashV":"4c60b247a2a4fe495819c5e6b042409fc6d9cad535ffa59599d88b203547ddb3","numberAttachments":1,"docType":"21P-530","numberPages":3,"ahash1":"b51f2aec3dbefff12026aed30860b3b2c73580e60d2e56ce7ce0c5699af575fe","numberPages1":1}',
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
          'fileSize' => 1_759_933, 'metaSize' => 419, 'md5' => '1I2+7z80I4jgvKenhclh5w==', 'md5hex' => 'd48dbeef3f342388e0bca7a785c961e7'
        )
        expect(response.status).to eq(200)
      end
    end
  end
end
