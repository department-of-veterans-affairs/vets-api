# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/redis_format.rb'

RSpec.describe CovidResearch::RedisFormat do
  let(:subject)      { described_class.new }
  let(:data)         { 'data' }
  let(:iv)           { 'iv' }
  let(:encoded_data) { Base64.encode64(data) }
  let(:encoded_iv)   { Base64.encode64(iv) }
  let(:raw)          { "{\"form_data\":\"#{encoded_data}\",\"iv\":\"#{encoded_iv}\"}" }

  describe 'encoding' do
    it 'automatically encodes the form_data' do
      subject.form_data = data

      expect(subject.instance_eval { @form_data }).to eq(encoded_data)
    end

    it 'automatically encodes the iv' do
      subject.iv = iv

      expect(subject.instance_eval { @iv }).to eq(encoded_iv)
    end
  end

  describe 'decoding' do
    let(:subject) { described_class.new(raw) }

    it 'automatically decodes the form_data' do
      expect(subject.form_data).to eq data
    end

    it 'automatically decodes the iv' do
      expect(subject.iv).to eq iv
    end
  end

  describe 'serialization' do
    it 'generates json with encoded values' do
      subject.form_data = data
      subject.iv = iv

      expect(subject.to_json).to eq(raw)
    end

    it 'initializes from a raw string' do
      sub = described_class.new(raw)

      expect(sub.form_data).to eq(data)
      expect(sub.iv).to eq(iv)
    end
  end
end
