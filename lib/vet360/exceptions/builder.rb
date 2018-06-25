# frozen_string_literal: true

require 'yaml'
require 'csv'

module Vet360
  module Exceptions
    class Builder
      attr_reader :known_exceptions, :stats, :error_codes, :needs_title, :needs_detail, :title, :detail

      def initialize
        @known_exceptions = Vet360::Exceptions::Parser.instance.known_exceptions
        @stats = initial_stats
        @error_codes  = []
        @needs_title  = []
        @needs_detail = []
      end

      def construct_exceptions_from_csv
        build_formatted_exceptions
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

          set_title_and_detail_for(code, row)

          error_codes << {
            code => {
              '<<': '*external_defaults',
              'title'  => title,
              'code'   => code,
              'detail' => detail,
              'status' => row['Status']&.strip || 400
            }
          }

          increment_stats_for(code)
        end
      end

      def error_codes_file
        Rails.root.join('spec', 'support', 'vet360', 'api_response_error_messages.csv')
      end

      # Makes the headers callable by stripping the empty spaces out. Depending on the CSV
      # data, there can be CSV Row headers with empty spaces. For example:
      #   row.headers => ["Message Code", " Sub Code", " Message Key", " Type", " Status", " State", " Queue", " Message Description"]
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

      def set_title_and_detail_for(code, row)
        known_exception = known_exceptions.find { |key, _| key == code }&.last

        @title  = known_exception&.dig('title')
        @detail = known_exception&.dig('detail').presence || row['Message Description']&.strip
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

      def write_exceptions_to_yaml
        path = Rails.root.join('tmp', 'test.yml')
        file = File.open(path, 'w')

        file.write error_codes.sort_by { |error| error&.keys&.first }.to_yaml
        file.close
      end

      # rubocop:disable Rails/Output
      def output_results_to_console
        puts
        p 'Needs a title:'
        p needs_title.presence || 0
        puts

        p 'Needs detail:'
        p needs_detail.presence || 0
        puts

        set_new_code_count

        stats.each { |key, value| p "#{key.to_s.titleize}: #{value}" }
      end
      # rubocop:enable Rails/Output

      def set_new_code_count
        stats[:new_codes] = stats[:total_created] - stats[:existing_codes]
      end
    end
  end
end
