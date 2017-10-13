# frozen_string_literal: true
require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      VCR.use_cassette('pension_burial/upload', match_requests_on: [:body]) do
        response = described_class.new.upload
        body = response.body

        expect(body['fileSize']).to eq(1226)
        expect(body['metaSize']).to eq(22)
        expect(response.status).to eq(200)
      end
    end
  end
end
