# frozen_string_literal: true

require 'rails_helper'

RSpec.describe PensionBurial::Service do
  describe '#upload' do
    it 'should upload a file' do
      header_matcher = lambda do |r1, r2|
        [r1, r2].each { |r| r.headers.delete('Content-Length') }
        expect(r1.headers).to eq(r2.headers)
      end

      VCR.use_cassette(
        'pension_burial/upload',
        match_requests_on: [header_matcher, :body, :method, :uri]
      ) do
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
        expect(body).to eq('Request was received successfully  [uuid: bd71f985-9bad-45c2-8b63-d052f544c27d] ')

        expect(response.status).to eq(200)
      end
    end
  end
end
