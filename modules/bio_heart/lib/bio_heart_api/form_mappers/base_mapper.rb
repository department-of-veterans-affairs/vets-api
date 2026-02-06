# frozen_string_literal: true

module BioHeartApi
  module FormMappers
    class BaseMapper
      def self.transform(params)
        new(params).call
      end

      def initialize(params)
        @params = params
      end

      def call
        raise NotImplementedError, 'Subclass must implement #call'
      end

      protected

      # Shared mapper utility methods go here

      # Format date hash to MM/DD/YYYY for IBM MMS
      #
      # @param date_hash [Hash, nil] Hash with 'month', 'day', 'year' keys
      # @return [String, nil] Formatted date string or nil
      def parse_date(date_hash)
        return nil unless date_hash && [date_hash['month'], date_hash['day'], date_hash['year']].none?(&:blank?)

        "#{format('%02d', date_hash['month'].to_i)}/#{format('%02d', date_hash['day'].to_i)}/#{date_hash['year']}"
      end

      # Build a full name from a name hash
      #
      # @param name_hash [Hash, nil] Hash with 'first', 'middle', 'last' keys
      # @return [String, nil] Full name or nil
      def build_full_name(name_hash)
        return nil unless name_hash

        parts = [
          name_hash['first'],
          name_hash['middle'],
          name_hash['last']
        ].compact.compact_blank

        parts.any? ? parts.join(' ') : nil
      end

      # Extract middle initial from name hash
      #
      # @param name_hash [Hash, nil] Hash with 'middle' key
      # @return [String, nil] First character of middle name or nil
      def extract_middle_initial(name_hash)
        return nil unless name_hash && name_hash['middle'].present?

        name_hash['middle'][0]
      end

      # Format SSN from hash to XXXXXXXXX
      #
      # @param ssn_hash [Hash, nil] Hash with 'first3', 'middle2', 'last4' keys
      # @return [String, nil] Formatted SSN or nil
      def format_ssn(ssn_hash)
        return nil unless ssn_hash && [ssn_hash['first3'], ssn_hash['middle2'], ssn_hash['last4']].none?(&:blank?)

        "#{ssn_hash['first3']}#{ssn_hash['middle2']}#{ssn_hash['last4']}"
      end
    end
  end
end
