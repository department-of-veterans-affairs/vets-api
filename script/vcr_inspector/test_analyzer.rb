# frozen_string_literal: true

require 'shellwords'

module VcrInspector
  class TestAnalyzer
    def self.find_tests_using(spec_root, modules_root, cassette_path)
      search_paths = [spec_root, modules_root]
      tests = search_paths.flat_map { |root| search_in_path(root, cassette_path) }
      tests.uniq { |t| t[:full_path] }
    end

    def self.search_in_path(root, cassette_path)
      return [] unless Dir.exist?(root)

      pattern = Shellwords.shellescape(cassette_path)
      root_escaped = Shellwords.shellescape(root)
      cmd = "grep -r #{pattern} #{root_escaped} --include='*_spec.rb' 2>/dev/null"
      output = `#{cmd}`

      parse_grep_output(output, root)
    end

    def self.parse_grep_output(output, root)
      tests = []
      output.each_line do |line|
        test_info = extract_test_info(line, root)
        tests << test_info if test_info
      end
      tests
    end

    def self.extract_test_info(line, root)
      return nil unless line =~ /^([^:]+):(\d+):(.*)/

      {
        file: Regexp.last_match(1).sub("#{root}/", ''),
        line: Regexp.last_match(2),
        content: Regexp.last_match(3).strip,
        full_path: Regexp.last_match(1)
      }
    end

    def self.cassette_usage_stats(spec_root, modules_root)
      # Find all cassette references
      search_paths = [spec_root, modules_root]
      usage = Hash.new(0)

      search_paths.each do |root|
        next unless Dir.exist?(root)

        root_escaped = Shellwords.shellescape(root)
        cmd = "grep -r 'VCR.use_cassette\\|cassette:' #{root_escaped} --include='*_spec.rb' 2>/dev/null"
        output = `#{cmd}`

        output.each_line do |line|
          # Extract cassette name from the line
          if line =~ /['"]([^'"]+)['"]/
            cassette_name = Regexp.last_match(1)
            usage[cassette_name] += 1
          end
        end
      end

      usage
    end
  end
end
