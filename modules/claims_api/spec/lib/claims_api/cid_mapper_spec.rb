# frozen_string_literal: true

require 'rails_helper'
require 'claims_api/cid_mapper'

describe ClaimsApi::CidMapper do
  ClaimsApi::CidMapper::CID_MAPPINGS.each do |key, value|
    context "when 'cid' is '#{key}'" do
      it "maps to #{value}" do
        mapped_value = ClaimsApi::CidMapper.new(cid: key).name
        expect(mapped_value).to eq(value)
      end
    end
  end

  context "when 'cid' is an unknown value" do
    cid = 'ABCDEFGHIJKLMNOP'

    it "returns an obfuscated version of the 'cid'" do
      mapped_value = ClaimsApi::CidMapper.new(cid:).name
      expect(mapped_value).to eq('Lighthouse')
    end
  end

  context "when 'cid' is 'nil'" do
    cid = nil

    it "returns 'no cid'" do
      mapped_value = ClaimsApi::CidMapper.new(cid:).name
      expect(mapped_value).to eq('no cid')
    end
  end

  context "when 'cid' is an empty string" do
    cid = ' '

    it "returns 'no cid'" do
      mapped_value = ClaimsApi::CidMapper.new(cid:).name
      expect(mapped_value).to eq('no cid')
    end
  end

  context "when 'cid' is blank" do
    cid = ''

    it "returns 'no cid'" do
      mapped_value = ClaimsApi::CidMapper.new(cid:).name
      expect(mapped_value).to eq('no cid')
    end
  end
end
