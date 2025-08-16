# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Common::FileHelpers do
  describe '.delete_file_if_exists' do
    context 'when file exists' do
      it 'deletes the file' do
        file_path = 'tmp/test_file.txt'
        File.write(file_path, 'test content')
        expect(File.exist?(file_path)).to be true

        described_class.delete_file_if_exists(file_path)

        expect(File.exist?(file_path)).to be false
      end
    end

    context 'when file does not exist' do
      it 'does not raise an error' do
        file_path = 'tmp/non_existent_file.txt'
        expect(File.exist?(file_path)).to be false

        expect { described_class.delete_file_if_exists(file_path) }.not_to raise_error
      end
    end

    context 'when path is nil' do
      it 'does not raise an error' do
        expect { described_class.delete_file_if_exists(nil) }.not_to raise_error
      end
    end

    context 'when path is empty string' do
      it 'does not raise an error' do
        expect { described_class.delete_file_if_exists('') }.not_to raise_error
      end
    end
  end

  describe '.random_file_path' do
    it 'generates a path in tmp directory' do
      path = described_class.random_file_path
      expect(path).to start_with('tmp/')
    end

    it 'generates unique paths' do
      path1 = described_class.random_file_path
      path2 = described_class.random_file_path
      expect(path1).not_to eq(path2)
    end

    it 'includes file extension when provided' do
      path = described_class.random_file_path('.pdf')
      expect(path).to end_with('.pdf')
    end

    it 'works without file extension' do
      path = described_class.random_file_path
      expect(path).not_to include('.')
    end
  end

  describe '.generate_random_file' do
    after do
      # Cleanup generated files
      Dir.glob('tmp/*').each do |file|
        File.delete(file) if File.file?(file)
      end
    end

    it 'creates a file with the specified content' do
      content = 'test file content'
      file_path = described_class.generate_random_file(content)

      expect(File.exist?(file_path)).to be true
      expect(File.read(file_path)).to eq(content)
    end

    it 'creates file with specified extension' do
      content = 'pdf content'
      file_path = described_class.generate_random_file(content, '.pdf')

      expect(file_path).to end_with('.pdf')
      expect(File.exist?(file_path)).to be true
      expect(File.read(file_path)).to eq(content)
    end

    it 'handles binary content' do
      binary_content = "\x89PNG\r\n\x1a\n".dup.force_encoding('BINARY')
      file_path = described_class.generate_random_file(binary_content, '.png')

      expect(File.exist?(file_path)).to be true
      expect(File.binread(file_path)).to eq(binary_content)
    end

    it 'returns the generated file path' do
      content = 'test'
      file_path = described_class.generate_random_file(content)

      expect(file_path).to be_a(String)
      expect(file_path).to start_with('tmp/')
    end
  end

  describe '.generate_clamav_temp_file' do
    after do
      # Cleanup generated files
      FileUtils.rm_rf('clamav_tmp')
    end

    it 'creates clamav_tmp directory if it does not exist' do
      FileUtils.rm_rf('clamav_tmp')
      expect(Dir.exist?('clamav_tmp')).to be false

      described_class.generate_clamav_temp_file('test content')

      expect(Dir.exist?('clamav_tmp')).to be true
    end

    it 'creates a file in clamav_tmp directory' do
      content = 'clamav test content'
      file_path = described_class.generate_clamav_temp_file(content)

      expect(file_path).to start_with('clamav_tmp/')
      expect(File.exist?(file_path)).to be true
      expect(File.read(file_path)).to eq(content)
    end

    it 'uses provided file name' do
      content = 'test'
      file_name = 'custom_name.txt'
      file_path = described_class.generate_clamav_temp_file(content, file_name)

      expect(file_path).to eq("clamav_tmp/#{file_name}")
      expect(File.exist?(file_path)).to be true
    end

    it 'generates random name when file_name is nil' do
      content = 'test'
      file_path = described_class.generate_clamav_temp_file(content, nil)

      expect(file_path).to start_with('clamav_tmp/')
      expect(File.exist?(file_path)).to be true
    end

    it 'handles binary content' do
      binary_content = "\x89PNG\r\n\x1a\n".dup.force_encoding('BINARY')
      file_path = described_class.generate_clamav_temp_file(binary_content, 'test.png')

      expect(File.exist?(file_path)).to be true
      expect(File.binread(file_path)).to eq(binary_content)
    end

    it 'returns the file path' do
      file_path = described_class.generate_clamav_temp_file('test')
      expect(file_path).to be_a(String)
      expect(file_path).to match(%r{^clamav_tmp/[a-f0-9]+$})
    end
  end
end
