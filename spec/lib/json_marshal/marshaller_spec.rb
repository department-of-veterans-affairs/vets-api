# frozen_string_literal: true

require 'rails_helper'
require 'json_marshal/marshaller'

describe JsonMarshal::Marshaller do
  subject { described_class }

  describe '#dump' do
    it 'returns a JSON string' do
      expect(subject.dump({ 'foo' => 1 })).to eq({ 'foo' => 1 }.to_json)
    end
  end

  describe '#load' do
    it 'returns a JSON string' do
      expect(subject.load({ 'foo' => 1 }.to_json)).to eq({ 'foo' => 1 })
    end
  end
end
