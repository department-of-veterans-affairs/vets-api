# frozen_string_literal: true

require 'yaml'
require 'open3'

namespace :feature_toggles do
  desc 'Validate feature toggle test coverage'
  task validate_coverage: :environment do
    puts '🔍 Validating feature toggle test coverage...'

    # Load feature configuration
    features_config = YAML.safe_load(Rails.root.join('config', 'features.yml').read)
    features_config['features'].keys

    # Get recently modified features (for PR validation)
    changed_files_output, status = Open3.capture2('git', 'diff', '--name-only', 'origin/main...HEAD')

    unless status.success?
      # Fallback to master if main doesn't exist
      # Try origin/master first, then fall back to master
      changed_files_output, status = Open3.capture2('git', 'diff', '--name-only', 'origin/master...HEAD')
      unless status.success?
        puts '⚠️  origin/master not available, trying master...'
        changed_files_output, status = Open3.capture2('git', 'diff', '--name-only', 'master...HEAD')
        unless status.success?
          puts '⚠️  Unable to determine changed files. Assuming features.yml was modified.'
          changed_files_output = "config/features.yml\n"
        end
      end
    end

    changed_files = changed_files_output.split("\n")

    # Check if features.yml was modified
    if changed_files.include?('config/features.yml')
      puts '📝 Features configuration file was modified, checking for new/modified features...'

      # Get the specific features that were added/modified
      diff_output, diff_status = Open3.capture2('git', 'diff', 'origin/master...HEAD', '--', 'config/features.yml')

      unless diff_status.success?
        puts '⚠️  origin/master not available, trying master...'
        diff_output, diff_status = Open3.capture2('git', 'diff', 'master...HEAD', '--', 'config/features.yml')
        unless diff_status.success?
          puts '⚠️  Unable to get diff for features.yml'
          exit 1
        end
      end

      modified_features = []
      diff_output.lines.each do |line|
        # Look for new feature definitions (lines starting with +, followed by feature name and colon)
        if line =~ /^\+\s+([a-zA-Z_][a-zA-Z0-9_]*):$/ && line.exclude?('features:')
          feature_name = Regexp.last_match(1)
          # Exclude the built-in test features used for specs
          unless %w[this_is_only_a_test this_is_only_a_test_two].include?(feature_name)
            modified_features << feature_name
          end
        end
      end

      if modified_features.any?
        puts "🧪 Checking test coverage for modified features: #{modified_features.join(', ')}"

        missing_coverage = []

        modified_features.each do |feature|
          puts "  Analyzing feature: #{feature}"

          # First check if this feature is actually used in the Ruby codebase
          unless feature_used_in_codebase?(feature)
            puts '    ℹ️  Feature not used in Ruby codebase (frontend-only or config-only) - skipping test validation'
            next
          end

          puts '    🔍 Feature is used in Ruby codebase - validating test coverage'

          # Search for specs testing this feature toggle in both enabled and disabled states
          enabled_specs = find_feature_toggle_specs(feature, true)
          disabled_specs = find_feature_toggle_specs(feature, false)

          has_enabled_test = !enabled_specs.empty?
          has_disabled_test = !disabled_specs.empty?

          puts "    - Enabled state tests: #{has_enabled_test ? '✅' : '❌'}"
          puts "    - Disabled state tests: #{has_disabled_test ? '✅' : '❌'}"

          unless has_enabled_test && has_disabled_test
            missing_coverage << {
              feature:,
              missing: [],
              enabled_specs:,
              disabled_specs:
            }
            missing_coverage.last[:missing] << 'enabled state' unless has_enabled_test
            missing_coverage.last[:missing] << 'disabled state' unless has_disabled_test
          end
        end

        if missing_coverage.any?
          puts "\n❌ Missing test coverage for feature toggles:"
          missing_coverage.each do |item|
            puts "  - #{item[:feature]}: Missing tests for #{item[:missing].join(' and ')}"
            show_enabled_test_info(item) if item[:enabled_specs].any?
            show_disabled_test_info(item) if item[:disabled_specs].any?
          end

          puts "\n📝 Each feature toggle must be tested in both enabled and disabled states."
          puts 'Use stubs as shown in the documentation:'
          puts '  # For enabled state:'
          puts "  allow(Flipper).to receive(:enabled?).with(:#{missing_coverage.first[:feature]}).and_return(true)"
          puts '  # For disabled state:'
          puts "  allow(Flipper).to receive(:enabled?).with(:#{missing_coverage.first[:feature]}).and_return(false)"
          puts "\nAlternatively, use the shared examples:"
          puts "  it_behaves_like 'feature toggle behavior', :#{missing_coverage.first[:feature]}"

          exit 1
        else
          puts '✅ All modified feature toggles have test coverage for both states'
        end
      else
        puts 'ℹ️  No new features detected in features.yml changes'
      end
    else
      puts 'ℹ️  Features configuration file was not modified'
    end

    puts '✅ Feature toggle coverage validation passed'
  end

  desc 'List all feature toggles and their test coverage status'
  task list_coverage: :environment do
    require_relative '../spec/support/feature_toggle_coverage'

    puts '📊 Feature Toggle Test Coverage Report'
    puts '=' * 50

    # Load all features
    features_config = YAML.safe_load(Rails.root.join('config', 'features.yml').read)
    all_features = features_config['features'].keys

    coverage_data = {}

    all_features.each do |feature|
      next if feature.include?('test') # Skip test features

      # Check if feature is actually used in codebase
      is_used = feature_used_in_codebase?(feature)

      if is_used
        enabled_specs = find_feature_toggle_specs(feature, true)
        disabled_specs = find_feature_toggle_specs(feature, false)

        coverage_data[feature] = {
          enabled: !enabled_specs.empty?,
          disabled: !disabled_specs.empty?,
          enabled_files: enabled_specs.size,
          disabled_files: disabled_specs.size,
          used_in_code: true
        }
      else
        coverage_data[feature] = {
          enabled: false,
          disabled: false,
          enabled_files: 0,
          disabled_files: 0,
          used_in_code: false
        }
      end
    end

    # Display results
    fully_covered = 0
    partially_covered = 0
    not_covered = 0

    coverage_data.each do |feature, data|
      unless data[:used_in_code]
        puts "ℹ️  UNUSED  #{feature} (frontend-only or config-only)"
        next
      end

      status = if data[:enabled] && data[:disabled]
                 fully_covered += 1
                 '✅ FULL'
               elsif data[:enabled] || data[:disabled]
                 partially_covered += 1
                 '⚠️  PARTIAL'
               else
                 not_covered += 1
                 '❌ NONE'
               end

      states = []
      states << "E:#{data[:enabled_files]}" if data[:enabled]
      states << "D:#{data[:disabled_files]}" if data[:disabled]
      state_info = states.any? ? "(#{states.join(', ')})" : ''

      puts "#{status.ljust(10)} #{feature} #{state_info}"
    end

    used_features_count = coverage_data.count { |_, data| data[:used_in_code] }
    unused_features_count = coverage_data.count { |_, data| !data[:used_in_code] }

    puts "\n📈 Summary:"
    puts "  Fully covered: #{fully_covered}"
    puts "  Partially covered: #{partially_covered}"
    puts "  Not covered: #{not_covered}"
    puts "  Used in Ruby code: #{used_features_count}"
    puts "  Frontend/config-only: #{unused_features_count}"
    puts "  Total features: #{coverage_data.size}"

    if used_features_count.positive?
      coverage_percentage = (fully_covered.to_f / used_features_count * 100).round(1)
      puts "  Coverage (used features): #{coverage_percentage}%"
    end
  end

  private

  def find_feature_toggle_specs(feature, enabled_state)
    search_patterns = [
      # Standard allow(Flipper) patterns with true/false
      "allow\\(Flipper\\).*receive.*enabled.*:#{feature}.*and_return\\(#{enabled_state}\\)",
      "allow\\(Flipper\\).*receive.*enabled.*'#{feature}'.*and_return\\(#{enabled_state}\\)",

      # Patterns with .with() method
      "allow\\(Flipper\\).*receive\\(:enabled\\?\\).*with\\(:#{feature}\\).*and_return\\(#{enabled_state}\\)",
      "allow\\(Flipper\\).*receive\\(:enabled\\?\\).*with\\('#{feature}'\\).*and_return\\(#{enabled_state}\\)"
    ]

    found_files = []

    search_patterns.each do |pattern|
      output, status = Open3.capture2('grep', '-r', '-l', '-E', pattern, 'spec/', '--include=*.rb')
      found_files.concat(output.split("\n")) if status.success?
    end

    found_files.uniq
  end

  def feature_used_in_codebase?(feature)
    # Search for actual Flipper.enabled? calls in the codebase (excluding specs)
    search_patterns = [
      # Flipper.enabled?(:feature) patterns
      "Flipper\\.enabled\\?\\(:#{feature}\\)",
      "Flipper\\.enabled\\?\\('#{feature}'\\)",
      "Flipper\\.enabled\\?\\([:'\"]#{feature}['\"])",

      # Flipper.enabled?(:feature, actor) patterns
      "Flipper\\.enabled\\?\\(:#{feature}\\s*,",
      "Flipper\\.enabled\\?\\('#{feature}'\\s*,",

      # Variable-based patterns like Flipper.enabled?(feature_name, user)
      "Flipper\\.enabled\\?\\(.*#{feature}"
    ]

    search_directories = %w[app/ lib/ modules/]

    search_patterns.each do |pattern|
      search_directories.each do |dir|
        next unless Dir.exist?(dir)

        output, status = Open3.capture2('grep', '-r', '-l', '-E', pattern, dir, '--include=*.rb')
        return true if status.success? && !output.strip.empty?
      end
    end

    false
  end

  def show_enabled_test_info(item)
    puts "    Found enabled tests in: #{item[:enabled_specs].take(3).join(', ')}"
  end

  def show_disabled_test_info(item)
    puts "    Found disabled tests in: #{item[:disabled_specs].take(3).join(', ')}"
  end
end
