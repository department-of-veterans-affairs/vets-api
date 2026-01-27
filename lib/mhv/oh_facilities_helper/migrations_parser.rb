# frozen_string_literal: true

require 'date'

module MHV
  module OhFacilitiesHelper
    # Standalone parser for oh_migrations_list settings format.
    # Used by both the Service class and validation scripts.
    #
    # Format: "date1:[id1,name1],[id2,name2];date2:[id3,name3]"
    #
    # Examples:
    #   Valid:   2026-04-11:[983,Test 1]
    #   Valid:   2026-04-11:[983,Test 1];2026-03-11:[984,Test 2]
    #   Valid:   2026-04-11:[983,Facility A],[984,Facility B];2026-05-01:[985,Facility C]
    #
    class MigrationsParser
      DATE_PATTERN = /\A\d{4}-\d{2}-\d{2}\z/
      FACILITY_PATTERN = /\[([^\]]+)\]/

      attr_reader :errors

      def initialize(input)
        @input = input.to_s.strip
        @errors = []
      end

      # Parses the input string into structured migration data
      # @return [Array<Hash>] Array of { migration_date:, facilities: [] }
      def parse
        @errors = []
        return [] if @input.empty?

        @input.split(';').filter_map do |migration_entry|
          migration_entry = migration_entry.strip
          next if migration_entry.empty?

          parse_single_migration_entry(migration_entry)
        end.compact
      end

      # Returns true if the input is valid (no parse errors)
      def valid?
        parse if @errors.empty? && !@parsed
        @errors.empty?
      end

      private

      # Parses a single migration entry like "2026-05-01:[123,Facility A],[456,Facility B]"
      def parse_single_migration_entry(entry)
        date_part, facilities_part = entry.split(':', 2)

        if date_part.nil? || date_part.strip.empty? || facilities_part.nil? || facilities_part.strip.empty?
          @errors << "Missing date or facilities in entry: '#{entry}'"
          return nil
        end

        date_str = date_part.strip

        unless date_str.match?(DATE_PATTERN)
          @errors << "Invalid date format '#{date_str}' - expected YYYY-MM-DD"
          return nil
        end

        # Validate it's a real calendar date
        begin
          Date.parse(date_str)
        rescue ArgumentError
          @errors << "Invalid calendar date '#{date_str}'"
          return nil
        end

        facilities = parse_facilities_from_string(facilities_part, date_str)
        if facilities.empty?
          @errors << "No valid facilities found for date '#{date_str}'"
          return nil
        end

        {
          migration_date: date_str,
          facilities:
        }
      end

      # Parses facilities from bracket-delimited string like "[123,Facility A],[456,Facility B]"
      def parse_facilities_from_string(facilities_string, date_str)
        matches = facilities_string.scan(FACILITY_PATTERN)

        if matches.empty?
          @errors << "No bracketed facilities found for date '#{date_str}'"
          return []
        end

        matches.filter_map do |match|
          parts = match[0].split(',', 2)

          if parts.length < 2 || parts[0].nil? || parts[0].strip.empty?
            @errors << "Invalid facility format '[#{match[0]}]' - expected [id,name]"
            next
          end

          {
            id: parts[0].strip,
            name: parts[1]&.strip || ''
          }
        end
      end
    end
  end
end
