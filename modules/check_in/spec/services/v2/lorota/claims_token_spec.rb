# frozen_string_literal: true

require 'rails_helper'

describe V2::Lorota::ClaimsToken do
  subject { described_class }

  describe 'constants' do
    it 'has a SIGNING_ALGORITHM' do
      expect(subject::SIGNING_ALGORITHM).to eq('RS256')
    end
  end

  describe '.build' do
    it 'returns an instance of ClaimsToken' do
      expect(subject.build).to be_an_instance_of(V2::Lorota::ClaimsToken)
    end
  end

  describe 'attributes' do
    it 'responds to expiration' do
      expect(subject.build({}).respond_to?(:expiration)).to be(true)
    end

    it 'responds to settings' do
      expect(subject.build({}).respond_to?(:settings)).to be(true)
    end

    it 'responds to check_in' do
      expect(subject.build({}).respond_to?(:check_in)).to be(true)
    end
  end

  describe '#sign_assertion' do
    let(:check_in) { double('CheckIn', uuid: '123-abc') }

    it 'is a String' do
      expect(subject.build(check_in:).sign_assertion).to be_a(String)
    end
  end

  describe '#claims' do
    let(:check_in) { double('CheckIn', uuid: '123-abc') }

    it 'is a Hash' do
      expect(subject.build(check_in:).claims).to be_a(Hash)
    end
  end

  describe '#rsa_key' do
    it 'is a OpenSSL::PKey::RSA' do
      expect(subject.build({}).rsa_key).to be_a(OpenSSL::PKey::RSA)
    end
  end

  describe '#issued_at_time' do
    it 'is an Integer' do
      expect(subject.build({}).issued_at_time).to be_a(Integer)
    end
  end

  describe '#expires_at_time' do
    it 'is an Integer' do
      expect(subject.build({}).expires_at_time).to be_a(Integer)
    end
  end
end
