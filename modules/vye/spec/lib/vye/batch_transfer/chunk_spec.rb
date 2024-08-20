# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::Chunk do
  let(:offset) { 0 }
  let(:block_size) { 1000 }
  let(:file) { Pathname.new('test.txt') }

  it 'can be instantiated' do
    expect(described_class.new(offset:, block_size:, file:)).to be_a described_class
  end

  describe '#load' do
    let(:filename) { 'test-0.txt' }
    let(:chunk) { described_class.new(offset:, block_size:, filename:) }
    let(:file) { instance_double(Pathname) }

    it 'downloads the dataset and laods it in to the database' do
      expect(chunk).to receive(:download).and_yield(file)
      expect(chunk).to receive(:import)

      chunk.load

      expect(chunk.instance_variable_get(:@file)).to eq(file)
    end
  end
end
