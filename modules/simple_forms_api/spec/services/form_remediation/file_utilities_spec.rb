# frozen_string_literal: true

require 'rails_helper'
require SimpleFormsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe SimpleFormsApi::FormRemediation::FileUtilities do
  let(:dummy_class) { Class.new { extend SimpleFormsApi::FormRemediation::FileUtilities } }
  let(:parent_dir) { '/parent_dir' }
  let(:temp_dir) { 'tmp/abc-123-archive/' }
  let(:unique_filename) { '10.8.24_form_20-10207_vagov_random-letters-n-numbers' }
  let(:s3_dir) { "#{parent_dir}/remediation" }
  let(:s3_key) { "#{s3_dir}/#{unique_filename}.zip" }

  before do
    allow(FileUtils).to receive(:mkdir_p)
    allow(FileUtils).to receive(:rm_rf)
    allow(Zip::File).to receive(:open)
    allow(CSV).to receive(:open).and_yield(double(:csv, '<<' => true))
  end

  describe '#zip_directory!' do
    subject(:zip_directory!) { dummy_class.zip_directory!(parent_dir, temp_dir, unique_filename) }

    let(:zip_file_path) { "#{temp_dir}#{unique_filename}.zip" }

    context 'when the temp directory exists' do
      before do
        allow(File).to receive_messages(directory?: true, file?: true)
        allow(Dir).to receive(:chdir).and_yield
        allow(Dir).to receive(:[]).with('**', '*').and_return(['file1.txt', 'file2.txt'])
      end

      it 'zips the directory and returns the zip file path' do
        expect(Zip::File).to receive(:open).with(zip_file_path, Zip::File::CREATE)
        expect(zip_directory!).to eq(zip_file_path)
      end
    end

    context 'when the temp directory does not exist' do
      it 'raises an error' do
        allow(File).to receive(:directory?).and_return(false)
        expect { zip_directory! }.to raise_error("Directory not found: #{temp_dir}")
      end
    end

    context 'when an error occurs during zipping' do
      let(:error_message) { 'zip error' }

      before do
        allow(File).to receive(:directory?).and_return(true)
        allow(Zip::File).to receive(:open).and_raise(StandardError.new(error_message))
      end

      it 'handles the error' do
        expect(dummy_class).to receive(:handle_error).with(
          "Failed to zip directory: #{temp_dir} to #{temp_dir}#{unique_filename}.zip",
          instance_of(StandardError)
        )
        begin
          zip_directory!
        rescue
          nil
        end
      end
    end
  end

  describe '#cleanup!' do
    subject(:cleanup!) { dummy_class.cleanup!('/tmp/to_cleanup') }

    it 'removes the directory' do
      expect(FileUtils).to receive(:rm_rf).with('/tmp/to_cleanup')
      cleanup!
    end
  end

  describe '#create_directory!' do
    subject(:create_directory!) { dummy_class.create_directory!('/tmp/new_dir') }

    it 'creates the directory' do
      expect(FileUtils).to receive(:mkdir_p).with('/tmp/new_dir')
      create_directory!
    end
  end

  describe '#build_local_path_from_s3' do
    subject(:build_local_path_from_s3) { dummy_class.build_local_path_from_s3(s3_dir, s3_key, temp_dir) }

    let(:local_file_path) { "#{temp_dir}#{unique_filename}.zip" }
    let(:pathname) { Pathname.new(local_file_path) }

    it 'builds the local path from the S3 path' do
      expect(FileUtils).to receive(:mkdir_p).with(pathname.dirname)
      expect(build_local_path_from_s3).to eq(local_file_path)
    end
  end

  describe '#build_path' do
    it 'builds the path for a directory' do
      path = dummy_class.build_path(:dir, parent_dir, 'remediation')
      expect(path).to eq("#{parent_dir}/remediation")
    end

    it 'builds the path for a file and appends the extension' do
      path = dummy_class.build_path(:file, parent_dir, 'remediation', unique_filename, ext: '.zip')
      expect(path).to eq("#{parent_dir}/remediation/#{unique_filename}.zip")
    end
  end

  describe '#write_file' do
    subject(:write_file) { dummy_class.write_file(dir_path, file_name, payload) }

    let(:dir_path) { '/tmp' }
    let(:file_name) { 'test.txt' }
    let(:payload) { 'file content' }

    it 'writes the file to the specified directory' do
      expect(File).to receive(:write).with("#{dir_path}/#{file_name}", payload)
      write_file
    end
  end

  describe '#unique_file_name' do
    subject(:unique_file_name) { dummy_class.unique_file_name(form_number, id) }

    let(:form_number) { '20-10207' }
    let(:id) { 'unique-form-id' }

    it 'builds a unique file path' do
      expect(unique_file_name).to eq("#{Time.zone.today.strftime('%-m.%d.%y')}_form_20-10207_vagov_#{id}")
    end
  end

  describe '#dated_directory_name' do
    subject(:dated_directory_name) { dummy_class.dated_directory_name(form_number) }

    let(:form_number) { '20-10207' }

    it 'builds a dated directory name' do
      expect(dated_directory_name).to eq("#{Time.zone.today.strftime('%-m.%d.%y')}-Form#{form_number}")
    end
  end

  describe '#write_manifest' do
    subject(:write_manifest) { dummy_class.write_manifest(row, path) }

    let(:row) { %w[2024-10-08 form 123 veteran_id John Doe] }
    let(:path) { '/tmp/manifest.csv' }
    let(:new_manifest) { true }

    it 'writes a new manifest file with headers' do
      expect(CSV).to receive(:open).with(path, 'ab').and_yield(double(:csv, '<<' => true))
      write_manifest
    end

    it 'handles errors during manifest writing' do
      allow(CSV).to receive(:open).and_raise(StandardError.new('write error'))
      expect(dummy_class).to(
        receive(:handle_error).with('Failed writing manifest for submission', instance_of(StandardError))
      )
      begin
        write_manifest
      rescue
        nil
      end
    end
  end
end
