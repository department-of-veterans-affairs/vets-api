# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::BingServiceError do
  subject { described_class.new('error_message') }

  it 'implements #errors which returns an array' do
    expect(subject.errors).to be_an(Array)
  end

  it '#status_code to be 500' do
    expect(subject.status_code).to eq(500)
  end
end
