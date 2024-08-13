# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Vye::BatchTransfer::Chunking do
  let(:total_lines) { 57 }
  let(:filename) { 'test.txt' }
  let(:block_size) { 10 }
  let(:block_count) { (total_lines / block_size.to_f).ceil }
  let(:chunking) { described_class.new(filename:, block_size:) }

  describe '#initialize' do
    it 'sets the attributes' do
      expect(chunking).to be_a described_class
      expect(chunking.send(:filename)).to eq filename
      expect(chunking.send(:block_size)).to eq block_size
      expect(chunking.send(:stem)).to eq 'test'
      expect(chunking.send(:ext)).to eq 'txt'
      expect(chunking.send(:chunks)).to be_empty
      expect(chunking.send(:split?)).to be false
    end
  end

  describe '#split' do
    let(:dirname) { instance_double(Pathname) }
    let(:dl_path) do
      Struct.new(:total_lines) do
        def each_line(&)
          total_lines.to_enum(:times).map { |i| "line #{i + 1}" }.each(&)
        end
      end.new(total_lines:)
    end
    let(:io_list) { 6.times.to_h { |i| ["test_#{i * 10}.txt", StringIO.new] } }
    let(:file_list) { 6.times.to_h { |i| ["test_#{i * 10}.txt", instance_double(Pathname)] } }
    let(:lines_in_last_file) { total_lines % block_size }
    let(:lines_in_file) { block_size }

    it 'downloads the file and chunks it' do
      file_list.each do |file, path|
        expect(dirname).to receive(:/).with(file).and_return(path)
        expect(path).to receive(:open).with('w').and_return(io_list[file])
      end

      io_list.each do |file, io|
        if file == 'test_50.txt'
          expect(io).to receive(:puts).exactly(lines_in_last_file).times
        else
          expect(io).to receive(:puts).exactly(lines_in_file).times
        end

        expect(io).to receive(:close) do
          io.close_read
          io.close_write
        end
      end

      allow(chunking).to receive(:dirname).and_return(dirname)
      expect(chunking).to receive(:download).with(filename).and_yield(dl_path)
      expect(chunking).to receive(:puts).exactly(total_lines).times.and_call_original

      expect(chunking.send(:split?)).to be(false)
      expect(chunking.split.length).to eq(6)
      expect(chunking.send(:split?)).to be(true)

      expect(chunking.split).to all(be_a(Vye::BatchTransfer::Chunk))
    end
  end

  describe '#close_current_handle' do
    let(:io) { instance_double(IO) }

    it 'closes the current handle' do
      expect(io).to receive(:closed?).and_return(false)
      expect(io).to receive(:close)

      chunking.instance_variable_set(:@current_handle, io)
      chunking.send(:close_current_handle)
    end
  end

  describe '#split!' do
    it 'sets the split flag' do
      chunking.send(:split!)
      expect(chunking.send(:split?)).to be true
    end
  end

  describe '#dirname' do
    let(:dirname) { instance_double(Pathname) }

    it 'returns the dirname' do
      chunking.instance_variable_set(:@dirname, dirname)
      expect(chunking.send(:dirname)).to eq dirname
    end

    it 'creates the dirname if it does not exist' do
      expect(chunking).to receive(:tmp_dir).and_return(dirname)
      expect(chunking.send(:dirname)).to eq dirname
    end
  end

  describe '#current_file' do
    let(:dirname) { instance_double(Pathname) }
    let(:file) { instance_double(Pathname) }
    let(:stem) { 'test' }
    let(:ext) { 'txt' }

    it 'returns the current file' do
      chunking.instance_variable_set(:@current_file, file)

      expect(chunking.send(:current_file)).to eq file
    end

    it 'returns a new file if none exists' do
      expect(chunking).to receive(:stem).and_return(stem)
      expect(chunking).to receive(:ext).and_return(ext)
      expect(chunking).to receive(:dirname).and_return(dirname)
      expect(dirname).to receive(:/).with("#{stem}_0.#{ext}").and_return(file)

      expect do
        expect(chunking.send(:current_file)).to eq file
      end.to change { chunking.send(:chunks).count }.by(1)
    end
  end

  describe '#current_handle' do
    let(:file) { instance_double(Pathname) }
    let(:io) { instance_double(IO) }

    it 'returns the current handle' do
      chunking.instance_variable_set(:@current_handle, io)
      expect(chunking.send(:current_handle)).to eq io
    end

    it 'creates a new handle if none exists' do
      expect(chunking).to receive(:current_file).and_return(file)
      expect(file).to receive(:open).with('w').and_return(io)

      expect(chunking.send(:current_handle)).to eq io
    end
  end

  describe '#puts' do
    let(:io) { instance_double(IO) }

    it 'sets up the next file if the line_num is the block_size' do
      chunking.instance_variable_set(:@line_num, block_size)
      chunking.instance_variable_set(:@current_handle, io)

      expect(io).to receive(:puts)
      expect(io).to receive(:close)

      chunking.send(:puts, 'line')

      expect(chunking.instance_variable_get(:@current_handle)).to be_nil
    end

    it "continues with the current file if the line_num isn't the block_size" do
      chunking.instance_variable_set(:@line_num, 0)
      chunking.instance_variable_set(:@current_handle, io)

      expect(io).to receive(:puts)
      expect(chunking.instance_variable_get(:@current_handle)).not_to be_nil

      chunking.send(:puts, 'line')
    end
  end
end
