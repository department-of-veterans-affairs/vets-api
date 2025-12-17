# frozen_string_literal: true

require_relative 'constants'

module VcrMcp
  # Finds spec files that use a given VCR cassette
  class SpecFinder
    VETS_API_ROOT = Constants::VETS_API_ROOT

    SPEC_DIRS = [
      'spec',
      'modules/*/spec'
    ].freeze

    # Patterns that indicate cassette usage in spec files
    CASSETTE_PATTERNS = [
      /VCR\.use_cassette\s*\(\s*['"]([^'"]+)['"]/,
      /use_cassette\s*\(\s*['"]([^'"]+)['"]/,
      /cassette:\s*['"]([^'"]+)['"]/
    ].freeze

    def self.find(cassette_name)
      new.find(cassette_name)
    end

    def find(cassette_name)
      results = []
      normalized_name = normalize_cassette_name(cassette_name)

      spec_files.each do |file|
        matches = find_in_file(file, normalized_name)
        results.concat(matches) unless matches.empty?
      end

      {
        cassette: cassette_name,
        specs: results,
        count: results.length
      }
    end

    private

    def normalize_cassette_name(name)
      # Remove .yml extension if present
      name.sub(/\.yml$/, '')
    end

    def spec_files
      @spec_files ||= SPEC_DIRS.flat_map do |pattern|
        Dir.glob(File.join(VETS_API_ROOT, pattern, '**', '*_spec.rb'))
      end
    end

    def find_in_file(file_path, cassette_name)
      content = File.read(file_path)
      return [] unless content.include?(cassette_name)

      matches = []
      seen_lines = Set.new

      content.each_line.with_index(1) do |line, line_num|
        find_cassette_matches_in_line(line, line_num, file_path, cassette_name) do |match_result|
          key = "#{file_path}:#{line_num}"
          next if seen_lines.include?(key)

          seen_lines.add(key)
          matches << match_result
        end
      end

      matches
    end

    def find_cassette_matches_in_line(line, line_num, file_path, cassette_name)
      CASSETTE_PATTERNS.each do |pattern|
        match = line.match(pattern)
        next unless match && cassette_matches?(match[1], cassette_name)

        yield build_match_result(file_path, line_num, line, match[1])
      end
    end

    def build_match_result(file_path, line_num, line, cassette_in_file)
      {
        file: relative_path(file_path),
        line: line_num,
        content: line.strip,
        cassette_in_file:
      }
    end

    def cassette_matches?(found, search)
      # Exact match
      return true if found == search

      # found ends with search (e.g., search "get_messages" matches "sm_client/messages/get_messages")
      return true if found.end_with?(search)

      # search ends with found
      return true if search.end_with?(found)

      # Partial path match
      found.include?(search) || search.include?(found)
    end

    def relative_path(file_path)
      file_path.sub("#{VETS_API_ROOT}/", '')
    end
  end
end
