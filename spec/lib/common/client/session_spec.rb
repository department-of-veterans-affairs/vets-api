# frozen_string_literal: true
require 'rails_helper'
require_dependency 'common/client/session'

describe Common::Client::Session do
  class DerivedClass < Common::Client::Session
    redis_store 'namespace'
    redis_ttl 900
    redis_key :user_id
  end

  context 'base class' do
    it 'raises NoMethodError unless class instance variables are provided' do
      expect { described_class.new }.to raise_error(NoMethodError)
    end
  end

  context 'valid?' do
    it 'returns true if user_id is present' do
      subject = DerivedClass.new(user_id: '1')
      expect(subject.user_id).to eq(1)
      expect(subject.valid?).to be_truthy
    end

    it 'returns false if user_id is not present' do
      subject = DerivedClass.new(user_id: '')
      expect(subject.user_id).to be_nil
      expect(subject.valid?).to be_falsey
    end
  end

  context 'expired?' do
    it 'returns true if expires_at is empty' do
      subject = DerivedClass.new(expires_at: '')
      expect(subject.expires_at).to be_nil
      expect(subject.expired?).to be_truthy
    end

    it 'returns true if expires_at is an expired time' do
      subject = DerivedClass.new(expires_at: 'Tue, 10 May 2016 16:40:17 GMT')
      expect(subject.expires_at).to be_a(Time)
      expect(subject.expired?).to be_truthy
    end

    it 'returns false if expires_at is not an expired time' do
      subject = DerivedClass.new(expires_at: 'Tue, 10 May 2099 16:40:17 GMT')
      expect(subject.expires_at).to be_a(Time)
      expect(subject.expired?).to be_falsey
    end
  end

  context 'with valid params and token' do
    subject { DerivedClass.new(user_id: '1', expires_at: 'Tue, 10 May 2016 16:40:17 GMT', token: 'token') }

    it 'responds to token' do
      expect(subject.token).to eq('token')
    end

    context 'inherited methods' do
      it 'responds to original_json but overridden to return nil since not loaded via json' do
        expect(subject.original_json).to eq(nil)
      end

      it 'responds to to_json' do
        expect(subject.to_json).to be_a(String)
      end
    end
  end
end
