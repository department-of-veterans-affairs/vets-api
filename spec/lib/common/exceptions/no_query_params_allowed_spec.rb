# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::NoQueryParamsAllowed do
  subject { described_class.new }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it 'the errors object has all relevant keys' do
    expect(subject.errors.first.to_hash)
      .to eq(title: 'No query params allowed',
             detail: 'No query params are allowed for this route',
             code: '400',
             status: '400')
  end
end