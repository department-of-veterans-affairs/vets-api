# frozen_string_literal: true
require 'rails_helper'

describe Common::Exceptions::RoutingError do
  subject { described_class.new }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it 'the errors object has all relevant keys' do
    expect(subject.errors.first.to_hash)
      .to eq(title: 'Not Found',
             detail: 'There are no routes matching your request',
             code: '411',
             status: '404')
  end
end
