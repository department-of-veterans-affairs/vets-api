# frozen_string_literal: true

require 'rails_helper'
require_relative '../../../script/vcr_inspector/test_analyzer'

RSpec.describe VcrInspector::TestAnalyzer do
  let(:temp_dir) { Dir.mktmpdir }
  let(:spec_root) { File.join(temp_dir, 'spec') }
  let(:modules_root) { File.join(temp_dir, 'modules') }

  before do
    FileUtils.mkdir_p(spec_root)
    FileUtils.mkdir_p(modules_root)
  end

  after { FileUtils.rm_rf(temp_dir) }

  def create_spec_file(filename, content)
    full_path = File.join(spec_root, filename)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  def create_module_spec_file(relative_path, content)
    full_path = File.join(modules_root, relative_path)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  def create_non_spec_file(filename, content)
    full_path = File.join(spec_root, filename)
    FileUtils.mkdir_p(File.dirname(full_path))
    File.write(full_path, content)
  end

  describe '.search_in_path' do
    it 'returns empty for nonexistent directory' do
      result = described_class.search_in_path('/nonexistent/path', 'test')
      expect(result).to eq([])
    end
  end

  describe '.parse_grep_output' do
    it 'extracts file and line' do
      output = "/path/to/spec/test_spec.rb:42:VCR.use_cassette('test')\n"

      result = described_class.parse_grep_output(output, '/path/to')

      expect(result.length).to eq(1)
      expect(result.first[:file]).to eq('spec/test_spec.rb')
      expect(result.first[:line]).to eq('42')
    end

    it 'extracts content' do
      output = "/root/spec/api_spec.rb:10:    VCR.use_cassette('my/cassette') do\n"

      result = described_class.parse_grep_output(output, '/root')

      expect(result.first[:content]).to eq("VCR.use_cassette('my/cassette') do")
    end

    it 'handles multiple lines' do
      output = "/root/spec/a_spec.rb:10:first match\n/root/spec/b_spec.rb:20:second match\n"

      result = described_class.parse_grep_output(output, '/root')

      expect(result.length).to eq(2)
    end

    it 'handles empty output' do
      result = described_class.parse_grep_output('', '/root')
      expect(result).to eq([])
    end

    it 'sets full_path' do
      output = "/root/spec/test_spec.rb:1:content\n"

      result = described_class.parse_grep_output(output, '/root')

      expect(result.first[:full_path]).to eq('/root/spec/test_spec.rb')
    end
  end

  describe '.extract_test_info' do
    it 'parses valid line' do
      line = "/root/spec/test_spec.rb:25:some content\n"

      result = described_class.extract_test_info(line, '/root')

      expect(result[:file]).to eq('spec/test_spec.rb')
      expect(result[:line]).to eq('25')
      expect(result[:content]).to eq('some content')
      expect(result[:full_path]).to eq('/root/spec/test_spec.rb')
    end

    it 'returns nil for invalid line' do
      result = described_class.extract_test_info('invalid line format', '/root')
      expect(result).to be_nil
    end

    it 'strips content' do
      line = "/root/spec/test_spec.rb:1:   spaced content   \n"

      result = described_class.extract_test_info(line, '/root')

      expect(result[:content]).to eq('spaced content')
    end

    it 'handles colons in content' do
      line = "/root/spec/test_spec.rb:10:cassette: 'my:cassette'\n"

      result = described_class.extract_test_info(line, '/root')

      expect(result[:content]).to eq("cassette: 'my:cassette'")
    end
  end

  describe '.find_tests_using' do
    it 'returns empty for no matches' do
      create_spec_file('test_spec.rb', 'describe "test" do; end')

      result = described_class.find_tests_using(spec_root, modules_root, 'nonexistent/cassette')

      expect(result).to eq([])
    end

    it 'finds matching spec' do
      create_spec_file('api_spec.rb', "VCR.use_cassette('my_service/test_cassette') do")

      result = described_class.find_tests_using(spec_root, modules_root, 'my_service/test_cassette')

      expect(result.length).to eq(1)
      expect(result.first[:file]).to include('api_spec.rb')
    end

    it 'searches both spec and modules' do
      create_spec_file('main_spec.rb', "VCR.use_cassette('shared/cassette') do")
      create_module_spec_file('my_module/spec/module_spec.rb', "VCR.use_cassette('shared/cassette') do")

      result = described_class.find_tests_using(spec_root, modules_root, 'shared/cassette')

      expect(result.length).to eq(2)
    end

    it 'only searches spec files' do
      create_spec_file('test_spec.rb', "cassette: 'my_cassette'")
      create_non_spec_file('helper.rb', "cassette: 'my_cassette'")

      result = described_class.search_in_path(spec_root, 'my_cassette')

      file_names = result.map { |r| r[:file] }
      expect(file_names).to include(a_string_including('test_spec.rb'))
      expect(file_names).not_to include(a_string_including('helper.rb'))
    end
  end
end
