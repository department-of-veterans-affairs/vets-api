# frozen_string_literal: true

require 'rails_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../../script/junit_to_runtime_log'

RSpec.describe JunitToRuntimeLog do
  let(:temp_dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(temp_dir) }

  describe '.aggregate_times' do
    it 'aggregates per-file times from JUnit XML' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="./spec/models/user_spec.rb" name="test one" time="1.5"/>
          <testcase file="./spec/models/user_spec.rb" name="test two" time="2.3"/>
          <testcase file="./spec/requests/api_spec.rb" name="test three" time="0.7"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec1.xml')
      File.write(xml_path, xml)

      result = described_class.aggregate_times([xml_path])

      expect(result).to eq(
        'spec/models/user_spec.rb' => 3.8,
        'spec/requests/api_spec.rb' => 0.7
      )
    end

    it 'aggregates across multiple XML files' do
      xml1 = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/models/user_spec.rb" name="test one" time="1.0"/>
        </testsuite>
      XML
      xml2 = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/models/user_spec.rb" name="test two" time="2.0"/>
          <testcase file="spec/services/auth_spec.rb" name="test three" time="3.0"/>
        </testsuite>
      XML
      path1 = File.join(temp_dir, 'rspec1.xml')
      path2 = File.join(temp_dir, 'rspec2.xml')
      File.write(path1, xml1)
      File.write(path2, xml2)

      result = described_class.aggregate_times([path1, path2])

      expect(result).to eq(
        'spec/models/user_spec.rb' => 3.0,
        'spec/services/auth_spec.rb' => 3.0
      )
    end

    it 'normalizes paths by stripping leading ./' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="./spec/foo_spec.rb" name="test" time="1.0"/>
          <testcase file="spec/foo_spec.rb" name="test2" time="2.0"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec.xml')
      File.write(xml_path, xml)

      result = described_class.aggregate_times([xml_path])

      expect(result).to eq('spec/foo_spec.rb' => 3.0)
    end

    it 'skips testcases missing file or time attributes' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase name="no file attr" time="1.0"/>
          <testcase file="spec/bar_spec.rb" name="no time attr"/>
          <testcase file="spec/ok_spec.rb" name="valid" time="5.0"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec.xml')
      File.write(xml_path, xml)

      result = described_class.aggregate_times([xml_path])

      expect(result).to eq('spec/ok_spec.rb' => 5.0)
    end

    it 'returns an empty hash when no XML files are provided' do
      result = described_class.aggregate_times([])

      expect(result).to be_empty
    end

    it 'skips malformed XML files and continues processing valid ones' do
      bad_xml_path = File.join(temp_dir, 'bad.xml')
      File.write(bad_xml_path, '<testsuite><testcase file="spec/a_spec.rb" time="1.0"')

      good_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/b_spec.rb" name="test" time="2.0"/>
        </testsuite>
      XML
      good_xml_path = File.join(temp_dir, 'good.xml')
      File.write(good_xml_path, good_xml)

      result = described_class.aggregate_times([bad_xml_path, good_xml_path])

      expect(result).to eq('spec/b_spec.rb' => 2.0)
    end

    it 'skips unreadable files and continues processing valid ones' do
      missing_path = File.join(temp_dir, 'nonexistent.xml')

      good_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/c_spec.rb" name="test" time="3.0"/>
        </testsuite>
      XML
      good_xml_path = File.join(temp_dir, 'good.xml')
      File.write(good_xml_path, good_xml)

      result = described_class.aggregate_times([missing_path, good_xml_path])

      expect(result).to eq('spec/c_spec.rb' => 3.0)
    end

    it 'skips XML files containing DOCTYPE declarations and continues processing valid ones' do
      doctype_xml_path = File.join(temp_dir, 'evil.xml')
      File.write(doctype_xml_path, <<~XML)
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE foo [<!ENTITY xxe "boom">]>
        <testsuite>
          <testcase file="spec/evil_spec.rb" name="test" time="1.0"/>
        </testsuite>
      XML

      good_xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/safe_spec.rb" name="test" time="2.0"/>
        </testsuite>
      XML
      good_xml_path = File.join(temp_dir, 'good.xml')
      File.write(good_xml_path, good_xml)

      result = described_class.aggregate_times([doctype_xml_path, good_xml_path])

      expect(result).to eq('spec/safe_spec.rb' => 2.0)
    end
  end

  describe '.write_log' do
    it 'writes a sorted runtime log in parallel_test format' do
      file_times = {
        'spec/models/z_spec.rb' => 1.2345,
        'spec/models/a_spec.rb' => 6.789
      }
      output_path = File.join(temp_dir, 'runtime.log')

      described_class.write_log(file_times, output_path)

      lines = File.readlines(output_path).map(&:chomp)
      expect(lines).to eq([
                            'spec/models/a_spec.rb:6.7890',
                            'spec/models/z_spec.rb:1.2345'
                          ])
    end

    it 'writes an empty file for empty input' do
      output_path = File.join(temp_dir, 'runtime.log')

      described_class.write_log({}, output_path)

      expect(File.read(output_path)).to eq('')
    end
  end
end
