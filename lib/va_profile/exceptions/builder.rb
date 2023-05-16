# frozen_string_literal: true

require 'yaml'
require 'csv'
require_relative 'parser'

module VAProfile
  module Exceptions
    class Builder
      attr_reader :known_exceptions, :stats, :error_codes, :needs_title, :needs_detail, :title, :detail, :status

      def initialize
        @known_exceptions = VAProfile::Exceptions::Parser.instance.known_exceptions
        @stats = initial_stats
        @error_codes = []
        @needs_title = []
        @needs_detail = []
      end

      # Takes the content from VAProfile's CSV of current error codes, and
      # converts them into formatted exceptions. These exceptions temporarily
      # live in tmp/test.yml, until a developer replaces the old VAProfile exceptions
      # in config/locales/exceptions.en.yml with these updated ones.
      #
      # A sample formatted exception in tmp/test.yml looks like this:
      #   - VET360_ADDR101:
      #     :<<: "*external_defaults"
      #     title: Address Type Size
      #     code: VET360_ADDR101
      #     detail: Address type size must be between 0 and 35.
      #     status: '400'
      #
      # It also outputs to the console a breakdown of what was done, and what
      # action needs to be taken by a developer. For example:
      #   "Needs a title:"
      #   ["VET360_CORE108", "VET360_CORE301", "VET360_CORE503", ...]
      #
      #   "Needs detail:"
      #   ["VET360_CORE301"]
      #
      #   "Existing Codes: 94"
      #   "New Codes: 74"
      #   "Total Created: 168"
      #   "Needs Title: 74"
      #   "Needs Detail: 1"
      #
      def construct_exceptions_from_csv
        build_formatted_exceptions
        include_custom_exceptions
        write_exceptions_to_yaml
        output_results_to_console
      end

      private

      def initial_stats
        {
          existing_codes: known_exceptions.count,
          new_codes: 0,
          total_created: 0,
          needs_title: 0,
          needs_detail: 0
        }
      end

      def build_formatted_exceptions
        CSV.foreach(error_codes_file, headers: true) do |row|
          row  = strip_row_headers(row)
          code = set_code_for(row)

          next if code.blank?
          next if duplicate?(code)

          set_attributes_for(code, row)
          insert_formatted_exception_for(code)
          increment_stats_for(code)
        end
      end

      def error_codes_file
        Rails.root.join('spec', 'support', 'va_profile', 'api_response_error_messages.csv')
      end

      # Makes the headers callable by stripping the empty spaces out. Depending on the CSV
      # data, there can be CSV Row headers with empty spaces. For example:
      #   row.headers => ["Message Code", " Sub Code", " Message Key", " Type",
      #                   " Status", " State", " Queue", " Message Description"]
      #
      # This prevents being able to call row['Message Description'], etc.
      #
      # @param row [CSV::Row] An instance of CSV::Row
      # @return [Hash] The original row, as a hash, with the headers stripped of empty spaces
      #
      def strip_row_headers(row)
        row.to_hash.transform_keys(&:strip)
      end

      def set_code_for(row)
        message_code = row['Message Code']&.upcase&.strip

        return if message_code.blank?

        "VET360_#{message_code}"
      end

      def duplicate?(code)
        error_keys.include? code
      end

      def error_keys
        error_codes.map(&:keys).flatten
      end

      def set_attributes_for(code, row)
        known_exception = known_exceptions.find { |key, _| key == code }&.last

        @title  = known_exception&.dig('title')
        @detail = known_exception&.dig('detail').presence || row['Message Description']&.strip
        @status = known_exception&.dig('status').presence || row['Status']&.strip.presence || 400
      end

      def insert_formatted_exception_for(code, options = {})
        error_codes << {
          code => {
            '<<': '*external_defaults',
            'title' => options['title'].presence || title,
            'code' => code,
            'detail' => options['detail'].presence || detail,
            'status' => options['status'].presence || status
          }
        }
      end

      def increment_stats_for(code)
        if title.blank?
          stats[:needs_title] += 1
          needs_title << code
        end

        if detail.blank?
          stats[:needs_detail] += 1
          needs_detail << code
        end

        stats[:total_created] += 1
      end

      def include_custom_exceptions
        custom_exceptions.each do |custom_exception|
          code    = custom_exception.first
          details = custom_exception.last

          insert_formatted_exception_for(code, details)
          stats[:total_created] += 1
        end
      end

      def custom_exceptions
        new_exceptions = error_keys

        known_exceptions.each_with_object([]) do |known_exception, custom|
          next if new_exceptions.include?(known_exception.first)

          custom << known_exception
        end
      end

      def write_exceptions_to_yaml
        path = Rails.root.join('tmp', 'test.yml')
        file = File.open(path, 'w')

        file.write '# BEGIN SCRIPT-GENERATED VAProfile EXCEPTIONS'
        file.write error_codes.sort_by { |error| error&.keys&.first }.to_yaml
        file.write '# END SCRIPT-GENERATED VAProfile EXCEPTIONS'
        file.close
      end

      # rubocop:disable Rails/Output
      def output_results_to_console
        puts
        puts 'Needs a title:'
        puts needs_title.presence || 0
        puts

        puts 'Needs detail:'
        puts needs_detail.presence || 0
        puts

        set_new_code_count

        stats.each { |key, value| puts "#{key.to_s.titleize}: #{value}" }
      end
      # rubocop:enable Rails/Output

      def set_new_code_count
        stats[:new_codes] = stats[:total_created] - stats[:existing_codes]
      end
    end
  end
end
