# frozen_string_literal: true

require 'English'
require 'open3'
require_relative 'constants'
require_relative 'inspector'

module VcrMcp
  # Validates VCR cassettes for sensitive data
  class Validator
    VETS_API_ROOT = Constants::VETS_API_ROOT
    CASSETTE_ROOT = Constants::CASSETTE_ROOT

    # Sensitive data patterns with severity levels
    SENSITIVE_PATTERNS = {
      # Veteran Identifiers - CRITICAL
      icn: {
        name: 'ICN (Integration Control Number)',
        patterns: [
          /\b\d{10}V\d{6}\b/, # Standard ICN: 10 digits + V + 6 digits
          /"icn"\s*:\s*"[^"]+"/i,           # JSON key "icn": "value"
          /icn[=:]\s*["']?\d+V\d+/i         # Query param or assignment
        ],
        severity: :critical,
        description: 'Unique veteran identifier - must be filtered'
      },

      ssn: {
        name: 'Social Security Number',
        patterns: [
          /\b\d{3}-\d{2}-\d{4}\b/,          # 123-45-6789
          /"ssn"\s*:\s*"[^"]+"/i,           # JSON key
          /"social_security_number"\s*:\s*"[^"]+"/i
        ],
        severity: :critical,
        description: 'SSN - must never appear in cassettes'
      },

      # Auth Tokens - HIGH
      bearer_token: {
        name: 'Bearer/Access Token',
        patterns: [
          /Bearer\s+[A-Za-z0-9\-_.]{20,}/i,
          /"access_token"\s*:\s*"[^"]{20,}"/i,
          /"token"\s*:\s*"[^"]{20,}"/i,
          /Authorization:\s*Bearer\s+[^\s"]+/i
        ],
        severity: :high,
        description: 'Auth tokens should be filtered via filter_sensitive_data'
      },

      api_key: {
        name: 'API Key',
        patterns: [
          /api[_-]?key[=:]\s*["']?[A-Za-z0-9\-_]{16,}/i,
          /"apikey"\s*:\s*"[^"]+"/i,
          /X-API-Key:\s*[^\s"]+/i,
          /appToken[=:]\s*["']?[A-Za-z0-9\-_]+/i
        ],
        severity: :high,
        description: 'API keys must be filtered'
      },

      mhv_correlation_id: {
        name: 'MHV Correlation ID',
        patterns: [
          /"mhv_correlation_id"\s*:\s*"[^"]+"/i,
          /mhvCorrelationId[=:]\s*["']?[^"'\s,}]+/i,
          /mhv_correlation_id[=:]\s*\d+/i
        ],
        severity: :high,
        description: 'MHV IDs should be filtered or use test values'
      },

      edipi: {
        name: 'EDIPI (DoD ID)',
        patterns: [
          /"edipi"\s*:\s*"[^"]+"/i,
          /"edipi"\s*:\s*\d+/i
        ],
        severity: :high,
        description: 'EDIPI should be filtered'
      },

      participant_id: {
        name: 'Participant ID',
        patterns: [
          /"participant_id"\s*:\s*"?\d+/i,
          /participantId[=:]\s*\d+/i
        ],
        severity: :high,
        description: 'Participant IDs should use test values'
      },

      file_number: {
        name: 'VA File Number',
        patterns: [
          /"file_number"\s*:\s*"[^"]+"/i,
          /fileNumber[=:]\s*["']?[^"'\s,}]+/i
        ],
        severity: :high,
        description: 'VA file numbers should be filtered'
      },

      # PII - MEDIUM
      email: {
        name: 'Email Address',
        patterns: [
          /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/
        ],
        severity: :medium,
        description: 'Consider using fake emails (test@example.com)'
      },

      phone: {
        name: 'Phone Number',
        patterns: [
          /\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b/,
          /"phone"\s*:\s*"[^"]+"/i,
          /"phone_number"\s*:\s*"[^"]+"/i
        ],
        severity: :medium,
        description: 'Consider using fake phone numbers'
      },

      address: {
        name: 'Street Address',
        patterns: [
          /"street"\s*:\s*"[^"]+"/i,
          /"address_line1"\s*:\s*"[^"]+"/i,
          /"addressLine1"\s*:\s*"[^"]+"/i
        ],
        severity: :medium,
        description: 'Consider using fake addresses'
      },

      date_of_birth: {
        name: 'Date of Birth',
        patterns: [
          /"birth_date"\s*:\s*"[^"]+"/i,
          /"dob"\s*:\s*"[^"]+"/i,
          /"date_of_birth"\s*:\s*"[^"]+"/i,
          /"birthDate"\s*:\s*"[^"]+"/i
        ],
        severity: :medium,
        description: 'DOB may be sensitive depending on context'
      }
    }.freeze

    # Known safe/test patterns that should not trigger warnings
    SAFE_PATTERNS = [
      # Common test ICNs
      /1012853550V207426/,     # Common test user
      /1013032368V131456/,     # Another test user
      /0000000000V000000/,     # Obvious placeholder
      /1234567890V123456/,     # Obvious test pattern

      # Test SSNs
      /123-45-6789/,
      /000-00-0000/,
      /987-65-4320/,

      # Test emails
      /test@example\.com/i,
      /user@example\.com/i,
      /va\.api\.user\+[^@]*@gmail\.com/i,

      # Already filtered markers
      /<FILTERED>/i,
      /\[FILTERED\]/i,
      /<REDACTED>/i,
      /XXXXX/
    ].freeze

    def self.validate(cassette_path)
      new(cassette_path).validate
    end

    def initialize(cassette_path)
      @cassette_path = cassette_path
    end

    def validate
      # Find the cassette file
      full_path = find_full_path
      return { error: "Cassette not found: #{@cassette_path}" } unless full_path

      # Read raw content for pattern matching
      content = File.read(full_path)

      # Find all sensitive data
      findings = scan_for_sensitive_data(content)

      # Compare with git HEAD if there are uncommitted changes
      git_comparison = compare_with_git(full_path)

      # Generate summary
      {
        cassette: @cassette_path,
        full_path: relative_path(full_path),
        findings:,
        summary: generate_summary(findings),
        git_comparison:,
        report: generate_report(findings, git_comparison)
      }
    end

    private

    def find_full_path
      result = Inspector.find_cassette(@cassette_path)
      return result if result.is_a?(String)
      return result.first if result.is_a?(Array) && !result.empty?

      nil
    end

    def relative_path(path)
      path&.sub("#{VETS_API_ROOT}/", '')
    end

    def scan_for_sensitive_data(content)
      findings = []

      SENSITIVE_PATTERNS.each do |key, config|
        config[:patterns].each do |pattern|
          content.scan(pattern) do |match|
            match_str = match.is_a?(Array) ? match.first : match.to_s

            # Skip if it matches a known safe pattern
            next if safe_pattern?(match_str)

            # Find line numbers
            line_numbers = find_line_numbers(content, match_str)

            findings << {
              type: key,
              name: config[:name],
              severity: config[:severity],
              match: sanitize_for_display(match_str),
              lines: line_numbers,
              description: config[:description]
            }
          end
        end
      end

      # Deduplicate by type and match
      findings.uniq { |f| [f[:type], f[:match]] }
    end

    def safe_pattern?(match)
      SAFE_PATTERNS.any? { |safe| match.match?(safe) }
    end

    def find_line_numbers(content, match)
      lines = []
      content.each_line.with_index(1) do |line, num|
        lines << num if line.include?(match)
      end
      lines.take(5) # Limit to first 5 occurrences
    end

    def sanitize_for_display(match)
      return match if match.length <= 10

      # Partially redact for display
      "#{match[0..5]}...#{match[-4..]}"
    end

    def generate_summary(findings)
      critical = findings.count { |f| f[:severity] == :critical }
      high = findings.count { |f| f[:severity] == :high }
      medium = findings.count { |f| f[:severity] == :medium }

      {
        critical:,
        high:,
        medium:,
        total: findings.length,
        safe_to_commit: critical.zero? && high.zero?
      }
    end

    def compare_with_git(full_path)
      rel_path = relative_path(full_path)

      original_content = fetch_git_original(rel_path)
      return nil unless original_content

      new_content = File.read(full_path)
      build_git_comparison(original_content, new_content)
    end

    def fetch_git_original(rel_path)
      git_status, _stderr, _status = Open3.capture3('git', 'status', '--porcelain', rel_path, chdir: VETS_API_ROOT)
      return nil if git_status.strip.empty?

      # rel_path is derived from relative_path() which only removes the VETS_API_ROOT prefix
      # from validated file paths within the cassette directory - not user input
      blob_ref = "HEAD:#{rel_path}"
      content, _stderr, status = Open3.capture3('git', 'cat-file', '-p', blob_ref, chdir: VETS_API_ROOT)
      return nil if content.empty? || !status.success?

      content
    end

    def build_git_comparison(original_content, new_content)
      original_count = count_interactions(original_content)
      new_count = count_interactions(new_content)

      {
        comparison_source: 'git HEAD',
        original_interactions: original_count,
        new_interactions: new_count,
        original_lines: original_content.lines.length,
        new_lines: new_content.lines.length,
        lines_changed: (new_content.lines.length - original_content.lines.length).abs,
        interaction_count_changed: original_count != new_count
      }
    end

    def count_interactions(content)
      yaml = YAML.safe_load(content)
      yaml&.dig('http_interactions')&.length || 0
    rescue => e
      warn "[Validator] Failed to count interactions: #{e.class}: #{e.message}"
      0
    end

    def generate_report(findings, git_comparison)
      report = []
      report.concat(report_header)
      report.concat(report_sensitivity_scan(findings))
      report.concat(report_summary(findings))
      report.concat(report_git_comparison(git_comparison)) if git_comparison
      report << ''
      report << ('=' * 80)
      report.join("\n")
    end

    def report_header
      [
        '=' * 80,
        'CASSETTE VALIDATION REPORT',
        '=' * 80,
        '',
        "Cassette: #{@cassette_path}",
        ''
      ]
    end

    def report_sensitivity_scan(findings)
      report = ['SENSITIVE DATA SCAN:', '']

      %i[critical high medium].each do |severity|
        report.concat(report_severity_section(findings, severity))
        report << ''
      end

      report
    end

    def report_severity_section(findings, severity)
      severity_findings = findings.select { |f| f[:severity] == severity }
      severity_label = severity.to_s.upcase

      return ["  ✓ #{severity_label}: None found"] if severity_findings.empty?

      icon = severity == :medium ? '⚠️ ' : '❌'
      lines = ["  #{icon} #{severity_label}:"]
      severity_findings.each { |finding| lines.concat(format_finding(finding)) }
      lines
    end

    def format_finding(finding)
      lines_str = finding[:lines].empty? ? '' : " (lines: #{finding[:lines].join(', ')})"
      [
        "     - #{finding[:name]}: #{finding[:match]}#{lines_str}",
        "       → #{finding[:description]}"
      ]
    end

    def report_summary(findings)
      summary = generate_summary(findings)
      safe_message = if summary[:safe_to_commit]
                       '  ✓ SAFE TO COMMIT (no critical or high severity findings)'
                     else
                       '  ❌ NOT SAFE TO COMMIT - Address critical/high findings first'
                     end

      [
        '-' * 80,
        'SUMMARY:',
        "  Critical: #{summary[:critical]}",
        "  High: #{summary[:high]}",
        "  Medium: #{summary[:medium]}",
        '',
        safe_message
      ]
    end

    def report_git_comparison(git_comparison)
      interaction_msg = if git_comparison[:interaction_count_changed]
                          '  ⚠️  Interaction count changed - verify this is expected'
                        else
                          '  ✓ Interaction count unchanged'
                        end

      [
        '',
        '-' * 80,
        'COMPARISON WITH GIT HEAD:',
        "  Interactions: #{git_comparison[:original_interactions]} → #{git_comparison[:new_interactions]}",
        "  Lines: #{git_comparison[:original_lines]} → #{git_comparison[:new_lines]}",
        interaction_msg,
        '',
        '  To see full diff: git diff <cassette_path>',
        '  To restore original: git checkout <cassette_path>'
      ]
    end
  end
end
