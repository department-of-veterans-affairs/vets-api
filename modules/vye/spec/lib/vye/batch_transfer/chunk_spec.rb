# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::Chunk do
  let(:offset) { 0 }
  let(:block_size) { 1000 }
  let(:file) { Pathname.new('test.txt') }
  let(:filename) { nil }

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

  context 'logging' do
    it 'writes to the logger when instantiated' do
      expect(Rails.logger).to receive(:info).with(
        "Vye::BatchTransfer::Chunk#initialize: offset=#{offset}, block_size=#{block_size}, " \
        "file=#{file}, filename=#{filename}"
      )

      expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#initialize: finished')

      described_class.new(offset:, block_size:, file:)
    end

    describe '#build_chunks' do
      let(:mock_chunks) { [double('chunk1'), double('chunk2')] }
      let(:mock_chunking) { instance_double(Vye::BatchTransfer::Chunking) }
      let(:filename) { 'test_file.csv' }

      before do
        allow(described_class).to receive(:feed_filename).and_return(filename)

        allow(Vye::BatchTransfer::Chunking)
          .to receive(:new)
          .with(filename:, block_size: anything)
          .and_return(mock_chunking)

        allow(mock_chunking).to receive(:split).and_return(mock_chunks)

        mock_chunks.each { |chunk| allow(chunk).to receive(:upload) }
      end

      # build_chunks calls upload so the expectations are here
      it 'writes to the logger when #build_chunks and #upload are called' do
        expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#build_chunks: starting')
        expect(Rails.logger).to receive(:info).with('Vye::BatchTransfer::Chunk#build_chunks: returning chunks')

        described_class.build_chunks
      end
    end
  end
end
