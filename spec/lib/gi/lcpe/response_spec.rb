# frozen_string_literal: true

require 'rails_helper'

describe GI::LCPE::Response do
  let(:raw_response) { double('FaradayResponse', body: {}, status:, response_headers:) }
  let(:status) { 200 }
  let(:response_headers) { { 'Etag' => v_fresh } }
  let(:v_fresh) { '3' }

  describe '.from' do
    it 'generates response object' do
      expect(described_class.from(raw_response)).to be_a described_class
    end

    it 'grabs version from response header and inserts into response body' do
      response = described_class.from(raw_response)
      expect(response.version).to eq(v_fresh)
    end
  end
end
