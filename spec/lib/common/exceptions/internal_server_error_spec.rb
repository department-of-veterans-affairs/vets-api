# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::InternalServerError do
  context 'with no exception provided' do
    it do
      expect { described_class.new }
        .to raise_error(ArgumentError, 'wrong number of arguments (given 0, expected 1)')
    end
  end

  context 'with invalid exception provided' do
    it do
      expect { described_class.new(nil) }
        .to raise_error(ArgumentError, 'an exception must be provided')
    end
  end

  context 'with valid exception provided' do
    subject { described_class.new(StandardError.new('some message')) }

    let(:environment) { 'production' }
    let(:env) { ActiveSupport::StringInquirer.new(environment) }

    before { stub_const('Rails', double('Rails', env:)) }

    context 'with environment = production' do
      it 'implements #errors which returns an array' do
        expect(subject.errors).to be_an(Array)
      end

      it 'the errors object has limited keys' do
        expect(subject.errors.first.to_hash)
          .to eq(title: 'Internal server error',
                 detail: 'Internal server error',
                 code: '500', status: '500')
      end
    end

    context 'with environment = development' do
      let(:environment) { 'development' }

      it 'the errors object has all relevant keys' do
        expect(subject.errors.first.to_hash)
          .to eq(title: 'Internal server error',
                 detail: 'Internal server error',
                 meta: { exception: 'some message', backtrace: nil },
                 code: '500', status: '500')
      end
    end
  end
end
