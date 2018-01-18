# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::Unauthorized do
  subject { described_class.new }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it 'the errors object has all relevant keys' do
    expect(subject.errors.first.to_hash)
      .to eq(title: 'Not authorized',
             detail: 'Not authorized',
             code: '401',
             status: '401')
  end

  context 'with optional detail attribute' do
    subject { described_class.new(detail: 'updated detail') }

    it 'has unique detail' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Not authorized',
               detail: 'updated detail',
               code: '401',
               status: '401')
    end
  end
end
