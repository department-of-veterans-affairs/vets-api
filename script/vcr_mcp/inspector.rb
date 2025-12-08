#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'base64'

require_relative 'constants'
require_relative 'cassette_parser'

module VcrMcp
  module Inspector
    CASSETTE_ROOT = Constants::CASSETTE_ROOT

    # Resolves and validates a path to prevent directory traversal attacks.
    # Returns nil if the path resolves outside CASSETTE_ROOT.
    def self.resolve_safe_path(path)
      resolved = File.expand_path(path, CASSETTE_ROOT)
      return nil unless resolved.start_with?(CASSETTE_ROOT)

      resolved
    end

    def self.find_cassette(query)
      # First, try the query as a path relative to CASSETTE_ROOT
      path = resolve_safe_path(query)
      return path if path && File.exist?(path)

      # Try with .yml extension
      path_with_ext = resolve_safe_path("#{query}.yml")
      return path_with_ext if path_with_ext && File.exist?(path_with_ext)

      # Try searching by basename only (ignore any path components in query for security)
      search_term = File.basename(query)
      matches = Dir.glob(File.join(CASSETTE_ROOT, "**/*#{search_term}*.yml"))

      if matches.empty?
        nil
      elsif matches.length == 1
        matches.first
      else
        # If exact match exists in the list, return it
        exact_match = matches.find { |m| File.basename(m, '.yml') == search_term }
        return exact_match if exact_match

        # Otherwise return list of matches
        matches
      end
    end

    def self.format_body(body_data)
      return '<NO BODY>' if body_data.nil?

      if body_data[:is_json]
        JSON.pretty_generate(body_data[:json])
      elsif body_data[:is_image]
        "<IMAGE: #{body_data[:image_type]}>"
      else
        body_data[:raw]
      end
    end

    def self.print_interaction(interaction, index)
      puts '=' * 80
      puts "INTERACTION #{index + 1} (Recorded: #{interaction[:recorded_at]})"
      puts '=' * 80

      req = interaction[:request]
      puts 'REQUEST:'
      puts "  #{req[:method].upcase} #{req[:uri]}"
      puts "  Headers: #{JSON.generate(req[:headers])}"
      puts '  Body:'
      puts format_body(req[:body]).gsub(/^/, '    ')

      res = interaction[:response]
      puts '-' * 80
      puts 'RESPONSE:'
      puts "  Status: #{res[:status][:code]} #{res[:status][:message]}"
      puts "  Headers: #{JSON.generate(res[:headers])}"
      puts '  Body:'
      puts format_body(res[:body]).gsub(/^/, '    ')
      puts "\n"
    end

    def self.inspect(query, _options = {})
      result = find_cassette(query)

      if result.nil?
        { error: "No cassette found matching '#{query}'" }
      elsif result.is_a?(Array)
        {
          error: 'Multiple cassettes found',
          matches: result.map { |path| path.sub("#{CASSETTE_ROOT}/", '') }
        }
      else
        cassette_path = result
        VcrMcp::CassetteParser.parse(cassette_path)
      end
    end
  end
end
