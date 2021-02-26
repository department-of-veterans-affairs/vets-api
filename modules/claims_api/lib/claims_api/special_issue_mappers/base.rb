# frozen_string_literal: true

module ClaimsApi
  module SpecialIssueMappers
    class Base
      # Convert to name from code of special issue.
      #
      # @param code [String] Short code of special issue
      # @return [String] Verbose name of special issue
      def name_from_code!(code)
        from_code(code)[:name]
      end

      def name_from_code(code)
        name_from_code!(code)
      rescue
        nil
      end

      # Convert to code from name of special issue.
      #
      # @param name [String] Verbose name of special issue
      # @return [String] Short code of special issue
      def code_from_name!(name)
        from_name(name)[:code]
      end

      def code_from_name(name)
        code_from_name!(name)
      rescue
        nil
      end

      protected

      def special_issues
        raise 'NotImplemented'
      end

      def from_code(code)
        special_issue = special_issues.find { |si| si[:code] == code }
        raise ::Common::Exceptions::InvalidFieldValue.new('special_issue', code) if special_issue.blank?

        special_issue
      end

      def from_name(name)
        special_issue = special_issues.find { |si| si[:name] == name }
        raise ::Common::Exceptions::InvalidFieldValue.new('special_issue', name) if special_issue.blank?

        special_issue
      end
    end
  end
end
