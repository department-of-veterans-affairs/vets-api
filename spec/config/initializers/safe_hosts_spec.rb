# frozen_string_literal: true

require 'rails_helper'

describe SAFE_HOSTS do
  subject { SAFE_HOSTS }

  it 'has an array of safe hosts' do
    expect(subject).to eq(['test.host', 'www.example.com', 'localhost', ''])
  end
end
