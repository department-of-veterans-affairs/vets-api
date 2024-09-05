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

    it 'returns a URI with the ICN hashed' do
      uri = URI.parse('http://example.com/1234567890V123456')
      anon_uri = URI.parse('http://example.com/441ab560b8fc574c6bf84d6c6105318b79455321a931ef701d39f4ff91894c64')
      expect(subject.anonymize_uri_icn(uri)).to eql(anon_uri)
    end
  end

  describe '#anonymize_icns' do
    let(:icn1) { '1234567890V123456' }
    let(:icn2) { '0987654321V654321' }
    let(:icn1_digest) { Digest::SHA256.hexdigest(icn1) }
    let(:icn2_digest) { Digest::SHA256.hexdigest(icn2) }
    let(:msg1_with_icn) { "This is a message with an ICN: #{icn1}" }
    let(:msg1_anon) { "This is a message with an ICN: #{icn1_digest}" }
    let(:msg2_with_two_icns) { "This is a message with two ICNs: #{icn1} and #{icn2}" }
    let(:msg2_anon) { "This is a message with two ICNs: #{icn1_digest} and #{icn2_digest}" }
    let(:msg3_w_identical_icns) { "ICN: #{icn1} and ICN: #{icn1}" }
    let(:msg3_anon) { "ICN: #{icn1_digest} and ICN: #{icn1_digest}" }
    let(:msg4_without_icn) { 'This is a message without an ICN' }

    it 'returns nil if the message is nil' do
      expect(subject.anonymize_icns(nil)).to be_nil
    end

    it 'returns a message with the ICN hashed' do
      expect(subject.anonymize_icns(msg1_with_icn)).to eql(msg1_anon)
    end

    it 'returns a message with all ICNs hashed' do
      expect(subject.anonymize_icns(msg2_with_two_icns)).to eql(msg2_anon)
    end

    it 'returns a message with two identical ICNs hashed' do
      expect(subject.anonymize_icns(msg3_w_identical_icns)).to eql(msg3_anon)
    end

    it 'returns the original message if the message does not contain an ICN' do
      expect(subject.anonymize_icns(msg4_without_icn)).to eql(msg4_without_icn)
    end
  end
end
