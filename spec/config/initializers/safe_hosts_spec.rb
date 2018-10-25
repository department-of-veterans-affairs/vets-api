# frozen_string_literal: true

require 'rails_helper'

describe SafeHosts do
  subject { SafeHosts }

  it 'has an array of safe hosts' do
    expect(subject).to eq(['test.host', 'www.example.com', 'localhost', ''])
  end
end
