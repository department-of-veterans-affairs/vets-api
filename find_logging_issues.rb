#!/usr/bin/env ruby
# frozen_string_literal: true

# Find all problematic logging patterns that could cause the backtrace error

class LoggingPatternFinder
  PATTERNS = [
    # Pattern 1: Passing exception.message to logger with a hash
    {
      pattern: /Rails\.logger\.(debug|info|warn|error|fatal)\(.*\.message.*,.*\{/,
      description: "Logger call with .message and a hash (likely has backtrace key)",
      severity: :high
    },
    # Pattern 2: String interpolation with backtrace
    {
      pattern: /Rails\.logger\.(debug|info|warn|error|fatal)\(.*#\{.*\.backtrace.*\}.*\)/,
      description: "String interpolation containing .backtrace",
      severity: :high
    },
    # Pattern 3: Logger with backtrace in string
    {
      pattern: /(logger|Rails\.logger)\.(debug|info|warn|error|fatal)\(".*backtrace.*"\)/,
      description: "Backtrace mentioned in string literal",
      severity: :medium
    },
    # Pattern 4: SemanticLogger with message string
    {
      pattern: /SemanticLogger.*\.(debug|info|warn|error|fatal)\(.*\.message/,
      description: "SemanticLogger with exception.message",
      severity: :high
    },
    # Pattern 5: Log with merge(backtrace: ...)
    {
      pattern: /\.merge\(.*backtrace:/,
      description: "Hash merge with backtrace key",
      severity: :medium
    }
  ]

  def initialize
    @findings = []
  end

  def scan
    puts "🔍 Scanning for problematic logging patterns..."
    puts "=" * 80
    puts

    scan_directory('app')
    scan_directory('lib')
    scan_directory('modules')
    scan_directory('config')

    generate_report
  end

  private

  def scan_directory(dir)
    return unless Dir.exist?(dir)

    Dir.glob("#{dir}/**/*.rb").each do |file|
      scan_file(file)
    end
  end

  def scan_file(file)
    content = File.read(file)
    lines = content.lines

    lines.each_with_index do |line, index|
      PATTERNS.each do |pattern_info|
        if line.match?(pattern_info[:pattern])
          @findings << {
            file: file,
            line_number: index + 1,
            line_content: line.strip,
            pattern: pattern_info[:description],
            severity: pattern_info[:severity]
          }
        end
      end
    end
  rescue => e
    puts "  ⚠️  Error scanning #{file}: #{e.message}"
  end

  def generate_report
    if @findings.empty?
      puts "✅ No problematic patterns found!"
      return
    end

    puts "⚠️  FOUND #{@findings.length} POTENTIAL ISSUES"
    puts "=" * 80
    puts

    # Group by severity
    high = @findings.select { |f| f[:severity] == :high }
    medium = @findings.select { |f| f[:severity] == :medium }

    if high.any?
      puts "🔴 HIGH PRIORITY (#{high.length})"
      puts "-" * 80
      high.each do |finding|
        print_finding(finding)
      end
      puts
    end

    if medium.any?
      puts "🟡 MEDIUM PRIORITY (#{medium.length})"
      puts "-" * 80
      medium.each do |finding|
        print_finding(finding)
      end
      puts
    end

    puts "=" * 80
    puts "📋 SUMMARY"
    puts "=" * 80
    puts "High priority issues: #{high.length}"
    puts "Medium priority issues: #{medium.length}"
    puts
    puts "Next steps:"
    puts "1. Review each high priority issue"
    puts "2. Change from: logger.error(exception.message, {backtrace: ...})"
    puts "3. Change to: logger.error(exception.message, {exception: exception, ...})"
    puts "   OR: logger.error(exception)"
  end

  def print_finding(finding)
    puts "📁 #{finding[:file]}:#{finding[:line_number]}"
    puts "   Pattern: #{finding[:pattern]}"
    puts "   Code: #{finding[:line_content]}"
    puts
  end
end

if __FILE__ == $0
  finder = LoggingPatternFinder.new
  finder.scan
end