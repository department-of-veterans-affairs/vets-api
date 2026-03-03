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

  describe '.group_for' do
    {
      'modules/check_in/app/controllers/foo.rb' => 'modules/check_in',
      'modules/check_in/spec/requests/foo_spec.rb' => 'modules/check_in',
      'modules/mobile/lib/thing.rb' => 'modules/mobile',
      'app/models/user.rb' => 'models',
      'spec/models/user_spec.rb' => 'models',
      'app/controllers/v0/foo_controller.rb' => 'controllers',
      'spec/requests/v0/foo_spec.rb' => 'controllers',
      'app/services/sign_in/token.rb' => 'services',
      'spec/services/sign_in/token_spec.rb' => 'services',
      'app/sidekiq/my_job.rb' => 'sidekiq',
      'spec/sidekiq/my_job_spec.rb' => 'sidekiq',
      'lib/rx/client.rb' => 'lib/rx',
      'spec/lib/rx/client_spec.rb' => 'lib/rx',
      'lib/lighthouse/service.rb' => 'lib/lighthouse',
      './spec/lib/lighthouse/service_spec.rb' => 'lib/lighthouse',
      'config/settings.yml' => 'config',
      'Gemfile' => 'Gemfile'
    }.each do |path, expected_group|
      it "maps #{path} to #{expected_group}" do
        expect(described_class.group_for(path)).to eq(expected_group)
      end
    end
  end

  describe '.find_slow_files' do
    it 'returns files exceeding the threshold whose group was touched' do
      file_times = {
        'spec/models/user_spec.rb' => 50.0,
        'spec/models/post_spec.rb' => 0.5,
        'spec/services/auth_spec.rb' => 45.0
      }
      changed_files = ['app/models/user.rb']

      result = described_class.find_slow_files(file_times, changed_files, threshold_pct: 2.0)

      expect(result.size).to eq(1)
      expect(result.first[:file]).to eq('spec/models/user_spec.rb')
      expect(result.first[:pct]).to be_within(0.5).of(52.4)
    end

    it 'excludes slow files in untouched groups' do
      file_times = {
        'spec/models/user_spec.rb' => 50.0,
        'spec/services/auth_spec.rb' => 50.0
      }
      changed_files = ['app/models/user.rb']

      result = described_class.find_slow_files(file_times, changed_files, threshold_pct: 2.0)

      expect(result.map { |r| r[:file] }).to eq(['spec/models/user_spec.rb'])
    end

    it 'returns empty when no files exceed threshold' do
      file_times = { 'spec/models/user_spec.rb' => 1.0, 'spec/models/post_spec.rb' => 1.0 }
      changed_files = ['app/models/user.rb']

      result = described_class.find_slow_files(file_times, changed_files, threshold_pct: 60.0)

      expect(result).to be_empty
    end

    it 'returns empty when total time is zero' do
      result = described_class.find_slow_files({}, ['app/models/user.rb'], threshold_pct: 2.0)

      expect(result).to be_empty
    end

    it 'matches module source changes to module spec files' do
      file_times = {
        'modules/check_in/spec/requests/travel_claims_spec.rb' => 80.0,
        'spec/models/user_spec.rb' => 20.0
      }
      changed_files = ['modules/check_in/app/controllers/travel_claims_controller.rb']

      result = described_class.find_slow_files(file_times, changed_files, threshold_pct: 2.0)

      expect(result.map { |r| r[:file] }).to eq(
        ['modules/check_in/spec/requests/travel_claims_spec.rb']
      )
    end
  end

  describe '.find_slow_examples' do
    it 'returns examples exceeding the threshold whose group was touched' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/models/user_spec.rb" name="is valid" time="25.0"/>
          <testcase file="spec/models/user_spec.rb" name="is fast" time="0.5"/>
          <testcase file="spec/services/auth_spec.rb" name="is slow" time="30.0"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec.xml')
      File.write(xml_path, xml)

      result = described_class.find_slow_examples([xml_path], ['app/models/user.rb'], threshold_sec: 20.0)

      expect(result.size).to eq(1)
      expect(result.first).to eq(file: 'spec/models/user_spec.rb', name: 'is valid', time: 25.0)
    end

    it 'excludes slow examples in untouched groups' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/services/auth_spec.rb" name="is slow" time="30.0"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec.xml')
      File.write(xml_path, xml)

      result = described_class.find_slow_examples([xml_path], ['app/models/user.rb'], threshold_sec: 20.0)

      expect(result).to be_empty
    end

    it 'returns results sorted by time descending' do
      xml = <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <testsuite>
          <testcase file="spec/models/a_spec.rb" name="medium" time="25.0"/>
          <testcase file="spec/models/b_spec.rb" name="slowest" time="40.0"/>
        </testsuite>
      XML
      xml_path = File.join(temp_dir, 'rspec.xml')
      File.write(xml_path, xml)

      result = described_class.find_slow_examples([xml_path], ['app/models/x.rb'], threshold_sec: 20.0)

      expect(result.map { |r| r[:name] }).to eq(%w[slowest medium])
    end
  end
end
