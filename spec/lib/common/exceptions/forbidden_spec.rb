# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::Forbidden do
  subject { described_class.new }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it 'the errors object has all relevant keys' do
    expect(subject.errors.first.to_hash)
      .to eq(title: 'Forbidden',
             detail: 'Forbidden',
             code: '403',
             status: '403')
  end

  context 'with optional detail attribute' do
    subject { described_class.new(detail: 'updated detail') }

    it 'has unique detail' do
      expect(subject.errors.first.to_hash)
        .to eq(title: 'Forbidden',
               detail: 'updated detail',
               code: '403',
               status: '403')
    end
  end
end
