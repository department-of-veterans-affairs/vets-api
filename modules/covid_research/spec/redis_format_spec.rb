# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/redis_format'

RSpec.describe CovidResearch::RedisFormat do
  subject             { described_class.new(crypto_class) }

  let(:crypto_class)  { double('crypto_class', new: crypto_double) }
  let(:crypto_double) { double('crypto', decrypt_form: raw_form, encrypt_form: encrypted_form) }
  let(:raw_form)      { '{"name":"Bob"}' }
  let(:secret_form)   { 'dkghdkghd' }
  let(:from_redis)    { "{\"form_data\":\"#{Base64.encode64(secret_form)}\"}" }
  let(:encrypted_form) do
    {
      form_data: secret_form
    }
  end

  describe '#from_redis' do
    it 'decrypts the form data' do
      expect(crypto_double).to receive(:decrypt_form)

      subject.from_redis(from_redis)
    end

    it 'stores the encrypted form data' do
      subject.from_redis(from_redis)

      expect(subject.instance_eval { @form_data }).to eq(secret_form)
    end
  end

  describe '#form_data' do
    it 'decrypts the form data' do
      expect(crypto_double).to receive(:decrypt_form)

      subject.form_data
    end
  end

  describe '#form_data=' do
    it 'encrypts the form data' do
      expect(crypto_double).to receive(:encrypt_form).with(raw_form)

      subject.form_data = raw_form
    end

    it 'stores the encrypted form data' do
      subject.form_data = raw_form

      expect(subject.instance_eval { @form_data }).to eq(secret_form)
    end
  end

  describe 'serialization' do
    it 'generates json with encoded values' do
      subject.form_data = raw_form

      expect(subject.to_json).to eq(from_redis)
    end

    it 'works with the JSON module' do
      subject.form_data = raw_form

      expect(JSON.generate(subject)).to eq(from_redis)
    end
  end
end
