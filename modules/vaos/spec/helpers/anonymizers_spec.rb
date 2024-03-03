# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VAOS::Anonymizers do
  describe '#anonymize_uri_icn' do
    it 'returns nil if the URI is nil' do
      expect(subject.anonymize_uri_icn(nil)).to be_nil
    end

    it 'returns the original URI if the URI does not contain an ICN' do
      uri = URI.parse('http://example.com')
      expect(subject.anonymize_uri_icn(uri)).to be(uri)
    end

    it 'returns a URI with the ICN anonymized' do
      uri = URI.parse('http://example.com/1234567890V123456')
      anon_uri = URI.parse('http://example.com/441ab560b8fc574c6bf84d6c6105318b79455321a931ef701d39f4ff91894c64')
      expect(subject.anonymize_uri_icn(uri)).to eql(anon_uri)
    end
  end
end
