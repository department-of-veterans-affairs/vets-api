# frozen_string_literal: true

module VcrInspector
  class TestAnalyzer
    def self.find_tests_using(spec_root, modules_root, cassette_path)
      # Search in both main spec and modules
      search_paths = [spec_root, modules_root]
      tests = []

      search_paths.each do |root|
        next unless Dir.exist?(root)

        # Use grep to find references
        pattern = cassette_path.gsub('/', '\/')
        cmd = "grep -r \"#{pattern}\" #{root} --include='*_spec.rb' 2>/dev/null"
        output = `#{cmd}`
        
        output.each_line do |line|
          if line =~ /^([^:]+):(\d+):(.*)/
            file_path = Regexp.last_match(1)
            line_number = Regexp.last_match(2)
            content = Regexp.last_match(3).strip
            
            tests << {
              file: file_path.sub("#{root}/", ''),
              line: line_number,
              content: content,
              full_path: file_path
            }
          end
        end
      end

      tests.uniq { |t| t[:full_path] }
    end

    def self.cassette_usage_stats(spec_root, modules_root)
      # Find all cassette references
      search_paths = [spec_root, modules_root]
      usage = Hash.new(0)

      search_paths.each do |root|
        next unless Dir.exist?(root)

        cmd = "grep -r 'VCR.use_cassette\\|cassette:' #{root} --include='*_spec.rb' 2>/dev/null"
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
