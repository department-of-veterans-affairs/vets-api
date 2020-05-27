# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::Internal::UnknownFormat do
  subject { described_class.new('application/foobar') }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it 'the errors object has all relevant keys' do
    expect(subject.errors.first.to_hash)
      .to eq(title: 'Not acceptable',
             detail: 'The resource could not be returned in the requested format',
             code: '406',
             status: '406')
  end
end
