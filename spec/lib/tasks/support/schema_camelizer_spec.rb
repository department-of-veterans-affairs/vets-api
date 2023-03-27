# frozen_string_literal: true

require 'rails_helper'
require './lib/tasks/support/schema_camelizer'

describe SchemaCamelizer do
  TEST_DIRECTORY = 'tmp/camel_schema_tests'
  TEST_SCHEMA_DIRECTORY = "#{TEST_DIRECTORY}/schemas".freeze
  TEST_RESULT_DIRECTORY = "#{TEST_DIRECTORY}/schemas_camelized".freeze

  before(:context) do
    # create directories for source and result schemas
    FileUtils.mkdir_p(TEST_SCHEMA_DIRECTORY)
    FileUtils.mkdir_p(TEST_RESULT_DIRECTORY)
  end

  after(:context) do
    FileUtils.remove_dir(TEST_DIRECTORY)
  end

  let(:snake_key_file) do
    schema = { 'snake_sound' => 'hiss', 'snake_style' => { 'snake_color' => 'black', 'snake_tongue' => 'forked' } }
    create_source_schema('snake_keys', schema)
  end

  let(:camel_key_file) do
    schema = { 'camelSound' => 'ptoo', 'camelStyle' => { 'camelColor' => 'brown', 'camelTongue' => 'rough' } }
    create_source_schema('camel_keys', schema)
  end

  def create_source_schema(name, hash)
    schema_file = "#{TEST_SCHEMA_DIRECTORY}/#{name}.json"

    File.open(schema_file, 'w') { |file| file.write(JSON.pretty_generate(hash)) }
    schema_file
  end

  describe '#camel_schema' do
    it 'camel-inflects keys' do
      schema = { 'cat_sound' => 'meow', 'dog_sound' => 'woof' }
      filename = create_source_schema('basic', schema)
      subject = SchemaCamelizer.new(filename)
      expect(subject.camel_schema.keys).to match %w[catSound dogSound]
    end

    it 'camel-inflects nested keys' do
      schema = { 'cat' => { 'mouth_sound' => 'meow', 'leg_count' => 4 } }
      filename = create_source_schema('nested_keys', schema)
      subject = SchemaCamelizer.new(filename)
      expect(subject.camel_schema['cat'].keys).to match %w[mouthSound legCount]
    end

    it 'camel-inflects values in "required" keys' do
      schema = { 'required' => %w[animal_sounds animal_names animal_outfits] }
      filename = create_source_schema('required_keys', schema)
      subject = SchemaCamelizer.new(filename)
      expect(subject.camel_schema['required']).to match %w[animalSounds animalNames animalOutfits]
    end
  end

  describe '#referenced_schemas' do
    it 'is empty with no references' do
      subject = SchemaCamelizer.new(snake_key_file)
      expect(subject.referenced_schemas).to be_empty
    end

    it 'is an Array of SchemaCamelizers for referenced schemas' do
      referenced_schema = { 'refer_to' => 'me' }
      referenced_schema_name = 'refer_to_me'
      referenced_filename = create_source_schema(referenced_schema_name, referenced_schema)

      schema = { 'refer_to' => 'something', '$ref' => referenced_filename.gsub("#{TEST_SCHEMA_DIRECTORY}/", '') }
      filename = create_source_schema('references', schema)
      subject = SchemaCamelizer.new(filename)

      expect(subject.referenced_schemas.count).to eq 1
      expect(subject.referenced_schemas.first).to be_a SchemaCamelizer
      expect(subject.referenced_schemas.first.name).to eq referenced_schema_name
    end
  end

  describe '#already_camelized' do
    it 'when the source schema has snake keys will be false' do
      subject = SchemaCamelizer.new(snake_key_file)
      expect(subject.already_camelized).to be false
    end

    it 'when the source schema has camel keys will be true' do
      subject = SchemaCamelizer.new(camel_key_file)
      expect(subject.already_camelized).to be true
    end
  end

  describe '#camel_path' do
    it 'is in schemas_camelized directory' do
      schema = { 'file_path' => 'will be updated' }
      filename = create_source_schema('use_a_new_camel_path', schema)
      subject = SchemaCamelizer.new(filename)
      expect(subject.camel_path).to include('schemas_camelized')
    end

    it 'can be set in the initializer' do
      filename = create_source_schema('manual_camel_path', { 'who' => 'cares' })
      camel_output = "#{TEST_DIRECTORY}/other/schemas/camel_destination.json"
      subject = SchemaCamelizer.new(filename, camel_output)
      expect(subject.camel_path).to include(camel_output)
    end
  end

  describe '#unchanged_schemas' do
    it 'is an array of names of schemas that are already_camelized' do
      subject = SchemaCamelizer.new(camel_key_file)
      expect(subject.unchanged_schemas.any?).to be true
      expect(subject.unchanged_schemas).to include(subject.name)
    end

    it 'is empty if the original schema was snake case' do
      subject = SchemaCamelizer.new(snake_key_file)
      expect(subject.unchanged_schemas).to be_empty
    end
  end

  describe '#save!' do
    it 'returns an array of paths to saved files' do
      referenced_filename1 = create_source_schema('refer_to_me_first', { 'refer_to' => 'me_first' })
      referenced_filename2 = create_source_schema('refer_to_me_second', { 'refer_to' => 'me_second' })

      schema = {
        'refer_to' => 'something',
        '$ref' => referenced_filename1.gsub("#{TEST_SCHEMA_DIRECTORY}/", ''),
        'deep_reference' => {
          '$ref' => referenced_filename2.gsub("#{TEST_SCHEMA_DIRECTORY}/", '')
        }
      }
      filename = create_source_schema('references', schema)
      subject = SchemaCamelizer.new(filename)

      saved_files = subject.save!
      expect(saved_files.count).to be > 1
      expect(saved_files).to include(*subject.referenced_schemas.collect(&:camel_path))
    end

    it 'writes files to the disk' do
      subject = SchemaCamelizer.new(snake_key_file)
      result = subject.save!
      expect(result.count).to be > 0
      result.each do |filename|
        expect(File.exist?(filename)).to be true
      end
    end

    it 'raises an exception when it is not in a schemas directory' do
      schema_file_in_weird_location = "#{TEST_DIRECTORY}/bad_location.json"
      schema = { 'signficant_data' => 'no' }
      File.open(schema_file_in_weird_location, 'w') { |file| file.write(JSON.pretty_generate(schema)) }

      subject = SchemaCamelizer.new(schema_file_in_weird_location)
      exception_text = 'expected `#camel_path` (tmp/camel_schema_tests/bad_location.json) ' \
                       'to be different from the given path'
      expect { subject.save! }.to raise_error(exception_text)
    end

    it 'creates directories for camel_path output' do
      subject = SchemaCamelizer.new(snake_key_file, "#{TEST_DIRECTORY}/new_directory/snake_in_camel.json")
      result = subject.save!
      expect(result.count).to be > 0
      result.each do |filename|
        expect(File.exist?(filename)).to be true
      end
    end
  end
end
