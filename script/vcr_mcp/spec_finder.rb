# frozen_string_literal: true

require 'set'

module VcrMcp
  # Finds spec files that use a given VCR cassette
  class SpecFinder
    VETS_API_ROOT = File.expand_path('../..', __dir__)

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
      matches = []
      seen_lines = Set.new

      # Check if file contains the cassette name at all (fast check)
      return matches unless content.include?(cassette_name)

      content.each_line.with_index(1) do |line, line_num|
        CASSETTE_PATTERNS.each do |pattern|
          match = line.match(pattern)
          next unless match

          found_cassette = match[1]
          # Check if the cassette matches (exact or partial)
          next unless cassette_matches?(found_cassette, cassette_name)

          # Deduplicate by file:line (multiple patterns might match same line)
          key = "#{file_path}:#{line_num}"
          next if seen_lines.include?(key)

          seen_lines.add(key)

          matches << {
            file: relative_path(file_path),
            line: line_num,
            content: line.strip,
            cassette_in_file: found_cassette
          }
        end
      end

      matches
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
