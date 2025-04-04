# frozen_string_literal: true

require 'rails_helper'
require 'gi/lcpe/response'

describe GI::LCPE::Response do
  let(:raw_response) { double('FaradayResponse', body: {}, status: 200, response_headers:) }
  let(:response_headers) { { 'Etag' => "W/\"#{v_fresh}\"" } }
  let(:v_fresh) { '3' }

  describe '.from' do
    it 'generates response object' do
      expect(described_class.from(raw_response)).to be_a described_class
    end

    it 'grabs version from response header and inserts into response body' do
      response = described_class.from(raw_response)
      expect(response.body).to include(version: v_fresh)
    end
  end

  describe '.version' do
    it 'returns version associated with response' do
      response = described_class.from(raw_response)
      expect(response.version).to eq(v_fresh)
    end
  end
end
