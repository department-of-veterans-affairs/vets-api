#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to analyze logging patterns across vets-api
# Usage: ruby analyze_logging_patterns.rb /path/to/vets-api

require 'find'
require 'json'

class LoggingPatternAnalyzer
  LOGGING_PATTERNS = {
    # Rails logger methods
    'Rails.logger.debug' => :rails_logger,
    'Rails.logger.info' => :rails_logger,
    'Rails.logger.warn' => :rails_logger,
    'Rails.logger.error' => :rails_logger,
    'Rails.logger.fatal' => :rails_logger,
    '::Rails.logger.debug' => :rails_logger,
    '::Rails.logger.info' => :rails_logger,
    '::Rails.logger.warn' => :rails_logger,
    '::Rails.logger.error' => :rails_logger,
    '::Rails.logger.fatal' => :rails_logger,

    # Sentry methods
    'Sentry.capture_exception' => :sentry_direct,
    'Sentry.capture_message' => :sentry_direct,
    'log_exception_to_sentry' => :sentry_helper,
    'log_message_to_sentry' => :sentry_helper,

    # Rails logger helpers
    'log_exception_to_rails' => :rails_helper,
    'log_message_to_rails' => :rails_helper,

    # StatsD
    'StatsD.increment' => :statsd,
    'StatsD.gauge' => :statsd,
    'StatsD.histogram' => :statsd,
    'StatsD.measure' => :statsd,

    # Logger instance methods
    'logger.debug' => :instance_logger,
    'logger.info' => :instance_logger,
    'logger.warn' => :instance_logger,
    'logger.error' => :instance_logger,
    'logger.fatal' => :instance_logger,
    '@logger.debug' => :instance_logger,
    '@logger.info' => :instance_logger,
    '@logger.warn' => :instance_logger,
    '@logger.error' => :instance_logger,
    '@logger.fatal' => :instance_logger,

    # puts/print (bad practice in production)
    'puts ' => :puts_print,
    'print ' => :puts_print,
    'p ' => :puts_print,
    'pp ' => :puts_print,
  }.freeze

  def initialize(root_path)
    @root_path = root_path
    @results = Hash.new { |h, k| h[k] = [] }
    @file_patterns = Hash.new { |h, k| h[k] = Hash.new(0) }
    @anti_patterns = []
  end

  def analyze
    puts "🔍 Analyzing logging patterns in: #{@root_path}"
    puts "=" * 80
    puts "\n📂 Scanning directories:"
    puts "  ✅ app/controllers"
    puts "  ✅ app/sidekiq"
    puts "  ✅ app/models"
    puts "  ✅ app/services"
    puts "  ✅ modules/"
    puts "  ✅ lib/"
    puts "  ❌ spec/ (excluded)"
    puts "  ❌ vendor/ (excluded)"
    puts "  ❌ node_modules/ (excluded)\n\n"

    scan_directory
    detect_anti_patterns
    generate_report
  end

  private

  def scan_directory
    ruby_files = []

    Find.find(@root_path) do |path|
      # Skip certain directories
      if FileTest.directory?(path)
        # Only skip build artifacts and vendor code, keep app/controllers, app/sidekiq, modules, lib
        if path.match?(%r{/(node_modules|tmp|log|coverage|\.git|vendor|public/packs)/})
          Find.prune
        else
          next
        end
      end

      # Only process Ruby files (including app/controllers, app/sidekiq, modules, lib)
      next unless path.end_with?('.rb')
      next if path.include?('/spec/') # Skip specs for main analysis

      ruby_files << path
    end

    puts "📁 Found #{ruby_files.length} Ruby files to analyze\n\n"

    ruby_files.each { |file| analyze_file(file) }
  end

  def analyze_file(file_path)
    content = File.read(file_path)
    relative_path = file_path.sub(@root_path, '').sub(%r{^/}, '')

    line_number = 0
    content.each_line do |line|
      line_number += 1

      LOGGING_PATTERNS.each do |pattern, category|
        if line.include?(pattern)
          @results[category] << {
            file: relative_path,
            line: line_number,
            code: line.strip,
            pattern: pattern
          }
          @file_patterns[relative_path][category] += 1
        end
      end
    end
  end

  def detect_anti_patterns
    puts "🚨 Detecting anti-patterns...\n\n"

    # Group by file and look for duplicates
    file_groups = Hash.new { |h, k| h[k] = [] }

    @results.each do |category, occurrences|
      occurrences.each do |occ|
        file_groups[occ[:file]] << { category: category, line: occ[:line], code: occ[:code] }
      end
    end

    # Check for multiple logging methods in same file
    file_groups.each do |file, logs|
      categories_used = logs.map { |l| l[:category] }.uniq

      if categories_used.length > 2
        @anti_patterns << {
          type: :multiple_logging_methods,
          file: file,
          categories: categories_used,
          count: logs.length,
          details: "File uses #{categories_used.length} different logging methods: #{categories_used.join(', ')}"
        }
      end

      # Check for both sentry and rails logging in close proximity
      sorted_logs = logs.sort_by { |l| l[:line] }
      sorted_logs.each_cons(2) do |log1, log2|
        if (log2[:line] - log1[:line]) <= 5
          if (log1[:category] == :sentry_helper && log2[:category] == :rails_helper) ||
             (log1[:category] == :rails_helper && log2[:category] == :sentry_helper)
            @anti_patterns << {
              type: :duplicate_logging,
              file: file,
              lines: [log1[:line], log2[:line]],
              details: "Both Sentry and Rails logging within 5 lines (lines #{log1[:line]}-#{log2[:line]})"
            }
          end
        end
      end

      # Check for puts/print statements
      if categories_used.include?(:puts_print)
        @anti_patterns << {
          type: :puts_in_production,
          file: file,
          details: "Using puts/print instead of proper logging"
        }
      end
    end
  end

  def generate_report
    puts "\n" + "=" * 80
    puts "📊 LOGGING PATTERN ANALYSIS REPORT"
    puts "=" * 80 + "\n\n"

    # Summary by category
    puts "📈 Summary by Logging Category:"
    puts "-" * 80
    @results.sort_by { |_, v| -v.length }.each do |category, occurrences|
      puts sprintf("  %-25s %5d occurrences", category.to_s.gsub('_', ' ').capitalize, occurrences.length)
    end
    puts "\n"

    # Top files by logging volume
    puts "📄 Top 20 Files by Logging Volume:"
    puts "-" * 80
    @file_patterns.sort_by { |_, patterns| -patterns.values.sum }.first(20).each do |file, patterns|
      total = patterns.values.sum
      breakdown = patterns.map { |k, v| "#{k}: #{v}" }.join(', ')
      puts sprintf("  %3d  %s", total, file)
      puts "       #{breakdown}\n\n"
    end

    # Anti-patterns
    if @anti_patterns.any?
      puts "\n🚨 ANTI-PATTERNS DETECTED:"
      puts "-" * 80

      grouped_anti = @anti_patterns.group_by { |ap| ap[:type] }

      grouped_anti.each do |type, patterns|
        puts "\n  #{type.to_s.gsub('_', ' ').upcase} (#{patterns.length} instances):"
        patterns.first(10).each do |pattern|
          puts "    • #{pattern[:file]}"
          puts "      #{pattern[:details]}"
        end
        puts "    ... and #{patterns.length - 10} more" if patterns.length > 10
      end
      puts "\n"
    end

    # Recommendations
    generate_recommendations

    # Export detailed results
    export_json_report
  end

  def generate_recommendations
    puts "\n💡 RECOMMENDATIONS FOR STANDARDIZATION:"
    puts "=" * 80

    recommendations = []

    # Check logging method diversity
    if @results.keys.length > 4
      recommendations << {
        priority: "HIGH",
        title: "Too many logging methods in use",
        description: "Platform uses #{@results.keys.length} different logging approaches. Recommend standardizing on 2-3 methods.",
        suggestion: "Consider: (1) log_exception_to_sentry/log_message_to_sentry for exceptions, (2) Rails.logger for general logging"
      }
    end

    # Check for duplicate logging anti-pattern
    duplicate_logging = @anti_patterns.select { |ap| ap[:type] == :duplicate_logging }
    if duplicate_logging.any?
      recommendations << {
        priority: "HIGH",
        title: "Duplicate logging detected",
        description: "Found #{duplicate_logging.length} instances of duplicate logging (both Sentry and Rails in same block).",
        suggestion: "Choose ONE method per error block. If using log_exception_to_sentry, remove log_exception_to_rails calls."
      }
    end

    # Check for puts/print usage
    if @results[:puts_print]&.any?
      recommendations << {
        priority: "MEDIUM",
        title: "Console output in production code",
        description: "Found #{@results[:puts_print].length} instances of puts/print statements.",
        suggestion: "Replace all puts/print with Rails.logger or appropriate logging method."
      }
    end

    # Check for direct Sentry calls vs helpers
    direct_sentry = @results[:sentry_direct]&.length || 0
    helper_sentry = @results[:sentry_helper]&.length || 0
    if direct_sentry > helper_sentry * 0.3
      recommendations << {
        priority: "LOW",
        title: "Inconsistent Sentry usage",
        description: "Mix of direct Sentry calls (#{direct_sentry}) and helper methods (#{helper_sentry}).",
        suggestion: "Prefer log_exception_to_sentry and log_message_to_sentry for consistency."
      }
    end

    recommendations.sort_by { |r| r[:priority] }.each_with_index do |rec, idx|
      puts "\n#{idx + 1}. [#{rec[:priority]}] #{rec[:title]}"
      puts "   Problem: #{rec[:description]}"
      puts "   Suggestion: #{rec[:suggestion]}"
    end

    puts "\n" + "=" * 80 + "\n"
  end

  def export_json_report
    report = {
      analysis_date: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
      root_path: @root_path,
      summary: {
        total_files_analyzed: @file_patterns.keys.length,
        total_logging_calls: @results.values.flatten.length,
        logging_methods_used: @results.keys.length,
        anti_patterns_found: @anti_patterns.length
      },
      by_category: @results.transform_values(&:length),
      anti_patterns: @anti_patterns,
      top_files: @file_patterns.sort_by { |_, v| -v.values.sum }.first(50).to_h
    }

    output_file = 'logging_analysis_report.json'
    File.write(output_file, JSON.pretty_generate(report))
    puts "📝 Detailed report exported to: #{output_file}\n\n"
  end
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby analyze_logging_patterns.rb /path/to/vets-api"
  exit 1
end

analyzer = LoggingPatternAnalyzer.new(ARGV[0])
analyzer.analyze