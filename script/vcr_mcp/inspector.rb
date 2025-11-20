#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'base64'

require_relative 'cassette_parser'

module VcrMcp
  module Inspector
    CASSETTE_ROOT = File.expand_path('../../spec/support/vcr_cassettes', __dir__)

    def self.find_cassette(query)
      if File.exist?(query)
        return query
      end

      # Try relative to CASSETTE_ROOT
      path = File.join(CASSETTE_ROOT, query)
      return path if File.exist?(path)
      
      path = File.join(CASSETTE_ROOT, "#{query}.yml")
      return path if File.exist?(path)

      # Try searching
      matches = Dir.glob(File.join(CASSETTE_ROOT, "**/*#{query}*.yml"))
      
      if matches.empty?
        nil
      elsif matches.length == 1
        matches.first
      else
        # If exact match exists in the list, return it
        exact_match = matches.find { |m| File.basename(m, '.yml') == query }
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
      puts "=" * 80
      puts "INTERACTION #{index + 1} (Recorded: #{interaction[:recorded_at]})"
      puts "=" * 80
      
      req = interaction[:request]
      puts "REQUEST:"
      puts "  #{req[:method].upcase} #{req[:uri]}"
      puts "  Headers: #{JSON.generate(req[:headers])}"
      puts "  Body:"
      puts format_body(req[:body]).gsub(/^/, '    ')
      
      res = interaction[:response]
      puts "-" * 80
      puts "RESPONSE:"
      puts "  Status: #{res[:status][:code]} #{res[:status][:message]}"
      puts "  Headers: #{JSON.generate(res[:headers])}"
      puts "  Body:"
      puts format_body(res[:body]).gsub(/^/, '    ')
      puts "\n"
    end

    def self.inspect(query, options = {})
      result = find_cassette(query)

      if result.nil?
        { error: "No cassette found matching '#{query}'" }
      elsif result.is_a?(Array)
        { 
          error: "Multiple cassettes found",
          matches: result.map { |path| path.sub(CASSETTE_ROOT + '/', '') }
        }
      else
        cassette_path = result
        parsed = VcrMcp::CassetteParser.parse(cassette_path)
        
        if options[:json]
          parsed
        else
          # For text output, we'll just print to stdout as before, 
          # but we might want to capture it if used as a library.
          # For now, let's just return the parsed object and let the caller handle display
          # or we can keep the print logic for the CLI.
          parsed
        end
      end
    end
  end
end

