# frozen_string_literal: true

require 'rails_helper'

describe Common::Exceptions::SentryIgnoredGatewayTimeout do
  it 'has the right message and status code' do
    error = described_class.new
    expect(error.message).to eq('Gateway timeout')
    expect(error.status_code).to eq(504)
  end
end
