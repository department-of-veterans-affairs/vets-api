# frozen_string_literal: true

require 'English'
require 'ostruct'

module VSPDanger
  HEAD_SHA = ENV.fetch('GITHUB_HEAD_REF', '').empty? ? `git rev-parse --abbrev-ref HEAD`.chomp.freeze : "origin/#{ENV.fetch('GITHUB_HEAD_REF')}"
  BASE_SHA = ENV.fetch('GITHUB_BASE_REF', '').empty? ? 'origin/master' : "origin/#{ENV.fetch('GITHUB_BASE_REF')}"

  class Runner
    def self.run
      prepare_git

      [
        SidekiqEnterpriseGaurantor.new.run,
        ChangeLimiter.new.run,
        MigrationIsolator.new.run,
        CodeownersCheck.new.run,
        GemfileLockPlatformChecker.new.run,
        FeatureToggleCoverage.new.run
      ]
    end

    def self.prepare_git
      `git fetch --depth=1000000 --prune origin +refs/heads/master:refs/remotes/origin/master`
    end
  end

  class Result
    ERROR = :error
    WARNING = :warning
    SUCCESS = :success

    attr_reader :severity, :message

    def initialize(severity, message)
      @severity = severity
      @message = message
    end

    def self.error(message)
      Result.new(ERROR, message)
    end

    def self.warn(message)
      Result.new(WARNING, message)
    end

    def self.success(message)
      Result.new(SUCCESS, message)
    end
  end

  class ChangeLimiter
    EXCLUSIONS = %w[
      *.csv *.json *.tsv *.txt *.md Gemfile.lock app/swagger modules/mobile/docs spec/fixtures/ spec/support/vcr_cassettes/
      modules/mobile/spec/support/vcr_cassettes/ db/seeds modules/vaos/app/docs modules/meb_api/app/docs
      modules/appeals_api/app/swagger/ *.bru *.pdf modules/*/spec/fixtures/* modules/*/spec/factories/*
    ].freeze
    PR_SIZE = { recommended: 200, maximum: 500 }.freeze

    def run
      return Result.error(error_message) if lines_changed > PR_SIZE[:maximum]
      return Result.warn(warning_message) if lines_changed > PR_SIZE[:recommended]

      Result.success('All set.')
    end

    private

    def error_message
      <<~EMSG
        This PR changes `#{lines_changed}` LoC (not counting whitespace/newlines).

        In order to ensure each PR receives the proper attention it deserves, those exceeding
        `#{PR_SIZE[:maximum]}` will not be reviewed, nor will they be allowed to merge. Please break this PR up into
        smaller ones.

        If you have reason to believe that this PR should be granted an exception, please see the
        [Submitting pull requests for approval - FAQ](https://depo-platform-documentation.scrollhelp.site/developer-docs/Submitting-pull-requests-for-approval.655032351.html#Submittingpullrequestsforapproval-FAQ).

        #{file_summary}

        Big PRs are difficult to review, often become stale, and cause delays.
      EMSG
    end

    def warning_message
      <<~EMSG
        This PR changes `#{lines_changed}` LoC (not counting whitespace/newlines).

        In order to ensure each PR receives the proper attention it deserves, we recommend not exceeding
        `#{PR_SIZE[:recommended]}`. Expect some delays getting reviews.

        #{file_summary}

        Big PRs are difficult to review, often become stale, and cause delays.
      EMSG
    end

    def file_summary
      <<~MSG
        <details>
          <summary>File Summary</summary>

          #### Files
          #{changes.collect { |change| "- #{change.file_name} (+#{change.insertions}/-#{change.deletions})" }.join "\n"}

          ####
          _Note: We exclude files matching the following when considering PR size:_

          ```
          #{EXCLUSIONS.join ', '}
          ```
        </details>
      MSG
    end

    def lines_changed
      @lines_changed ||= changes.sum(&:total_changes)
    end

    def changes
      @changes ||= `#{files_command}`.split("\n").map do |file_changes|
        insertions, deletions, file_name = file_changes.split "\t"
        insertions = insertions.to_i
        deletions = deletions.to_i

        next if insertions.zero? && deletions.zero?   # Skip unchanged files
        next if insertions == '-' && deletions == '-' # Skip Binary files (should be caught by `to_i` and `zero?`)

        # rename or copy - use the reported changes from earlier instead - `file_name` will not exist
        # eg: {lib => modules/pensions/lib}/pdf_fill/forms/va21p527ez.rb
        unless file_name.include?(' => ')
          lines = file_git_diff(file_name).split("\n")
          changed = { '+' => 0, '-' => 0 }
          lines.each do |line|
            next if (line =~ /^(\+[^+]|-[^-])/).nil? # Only changed lines, exclude metadata

            action = line[0].to_s
            clean_line = line[1..].strip # Remove leading '+' or '-'

            # Skip comments and empty lines
            next if clean_line.start_with?('#') || clean_line.empty?

            changed[action] += 1
          end

          # the actual count of changed lines
          insertions, deletions = changed.values
        end

        OpenStruct.new(
          total_changes: insertions + deletions,
          insertions:,
          deletions:,
          file_name:
        )
      end.compact
    end

    def files_command
      "git diff #{BASE_SHA}...#{HEAD_SHA} --numstat -w --ignore-blank-lines -- . #{exclusions}"
    end

    def exclusions
      EXCLUSIONS.map { |exclusion| "':!#{exclusion}'" }.join ' '
    end

    def file_git_diff(file_name)
      `git diff #{BASE_SHA}...#{HEAD_SHA} -w --ignore-blank-lines -- #{file_name}`
    end
  end

  class CodeownersCheck
    def fetch_git_diff
      `git diff #{BASE_SHA}...#{HEAD_SHA} -- .github/CODEOWNERS`
    end

    def error_message(required_group, index, line)
      <<~EMSG
        New entry on line #{index + 1} of CODEOWNERS does not include #{required_group}.
        Please add #{required_group} to the entry
        Offending line: `#{line}`
      EMSG
    end

    def run
      required_group = '@department-of-veterans-affairs/backend-review-group'
      exception_groups = %w[@department-of-veterans-affairs/octo-identity
                            @department-of-veterans-affairs/lighthouse-dash
                            @department-of-veterans-affairs/lighthouse-pivot
                            @department-of-veterans-affairs/lighthouse-banana-peels
                            @department-of-veterans-affairs/mobile-api-team
                            @department-of-veterans-affairs/accredited-representatives-admin
                            @department-of-veterans-affairs/benefits-admin]

      diff = fetch_git_diff

      if diff.empty?
        Result.success('CODEOWNERS file is unchanged.')
      else
        lines = diff.split("\n")

        lines.each_with_index do |line, index|
          next unless line.start_with?('+') # Only added lines
          next if line.start_with?('+++') # Skip metadata lines

          clean_line = line[1..].strip # Remove leading '+'

          # Skip comments, empty lines, or exceptions
          next if clean_line.start_with?('#') || clean_line.empty? ||
                  exception_groups.any? { |group| clean_line.include?(group) }

          unless clean_line.include?(required_group)
            return Result.error(error_message(required_group, index,
                                              clean_line))
          end
        end

        Result.success("All new entries in CODEOWNERS include #{required_group}.")
      end
    end
  end

  class MigrationIsolator
    DB_PATHS = ['db/migrate/', 'db/schema.rb'].freeze
    SEEDS_PATHS = ['db/seeds/', 'db/seeds.rb'].freeze

    def run
      return Result.error(error_message) if db_files.any? && app_files.any?

      Result.success('All set.')
    end

    private

    def error_message
      <<~EMSG
        Modified files in `db/migrate` or `db/schema.rb` changes should be the only files checked into this PR.

        <details>
          <summary>File Summary</summary>

          #### DB File(s)

          - #{db_files.join "\n- "}

          #### App File(s)

          - #{app_files.join "\n- "}
        </details>

        Application code must always be backwards compatible with the DB,
        both before and after migrations have been run. For more info:

        - [vets-api Database Migrations](https://depo-platform-documentation.scrollhelp.site/developer-docs/Vets-API-Database-Migrations.689832034.html)
      EMSG
    end

    def app_files
      files - db_files - seed_files
    end

    def db_files
      files.select { |file| DB_PATHS.any? { |db_path| file.include?(db_path) } }
    end

    def seed_files
      files.select { |file| SEEDS_PATHS.any? { |seed_path| file.include?(seed_path) } }
    end

    def files
      @files ||= `git diff #{BASE_SHA}...#{HEAD_SHA} --name-only`.split("\n")
    end
  end

  class GemfileLockPlatformChecker
    def run
      errors = []

      errors << "#{ruby_error_message}\n#{ruby_resolution_message}" if ruby_platform_removed?

      if (darwin_platform = darwin_platform_added)
        errors << "#{darwin_error_message(darwin_platform)}\n#{darwin_resolution_message(darwin_platform)}"
      end

      return Result.success('Gemfile.lock platform checks passed.') if errors.empty?

      errors << redownload_message

      Result.error(errors.join("\n\n"))
    end

    private

    def ruby_platform_removed?
      !platforms_section.include?('ruby')
    end

    def darwin_platform_added
      platforms_section[/.*-darwin-\d+/]
    end

    def ruby_error_message
      "You've removed the `ruby` platform from the Gemfile.lock! You must restore it before merging this PR."
    end

    def ruby_resolution_message
      <<~TEXT
        ```
        bundle lock --add-platform ruby
        ```
      TEXT
    end

    def darwin_error_message(darwin_platform)
      "You've added a Darwin platform to the Gemfile.lock: `#{darwin_platform.strip}`. You must remove it before merging this PR."
    end

    def darwin_resolution_message(darwin_platform)
      <<~TEXT
        ```
        bundle lock --remove-platform #{darwin_platform.strip}
        ```
      TEXT
    end

    def redownload_message
      <<~TEXT
        Redownload your gems after making the necessary changes:
        ```
        bundle install --redownload
        ```
      TEXT
    end

    def platforms_section
      @platforms_section ||= gemfile_lock.match(/^PLATFORMS$(.*?)^\n/m)[1]
    end

    def gemfile_lock
      File.read('Gemfile.lock')
    end
  end

  class FeatureToggleCoverage
    def run
      return Result.success('No features.yml changes detected.') unless features_yml_modified?

      modified_features = extract_modified_features
      return Result.success('No new feature toggles detected.') if modified_features.empty?

      missing_coverage = check_coverage(modified_features)
      return Result.success('All feature toggles have test coverage.') if missing_coverage.empty?

      Result.warn(coverage_warning_message(missing_coverage))
    end

    private

    def features_yml_modified?
      modified_files.include?('config/features.yml')
    end

    def modified_files
      @modified_files ||= `git diff #{BASE_SHA}...#{HEAD_SHA} --name-only`.split("\n")
    end

    def extract_modified_features
      diff_output = `git diff #{BASE_SHA}...#{HEAD_SHA} -- config/features.yml`
      modified_features = []

      diff_output.lines.each do |line|
        # Look for new feature definitions (lines starting with +, followed by feature name and colon)
        if line =~ /^\+\s+([a-zA-Z_][a-zA-Z0-9_]*):$/ && !line.include?('features:')
          feature_name = ::Regexp.last_match(1)
          # Exclude test features
          modified_features << feature_name unless feature_name.include?('test')
        end
      end

      modified_features
    end

    def check_coverage(features)
      missing_coverage = []

      features.each do |feature|
        # Skip features that aren't actually used in Ruby codebase
        next unless feature_used_in_codebase?(feature)

        enabled_specs = find_feature_toggle_specs(feature, true)
        disabled_specs = find_feature_toggle_specs(feature, false)

        has_enabled_test = !enabled_specs.empty?
        has_disabled_test = !disabled_specs.empty?

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

      missing_coverage
    end

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
        output = `grep -r -l -E "#{pattern}" spec/ --include=*.rb 2>/dev/null`
        found_files.concat(output.split("\n")) if $CHILD_STATUS.success?
      end

      found_files.uniq.compact
    end

    def coverage_warning_message(missing_coverage)
      message = ["⚠️ **Feature Toggle Test Coverage Missing**\n"]
      message << "The following feature toggles were added but don't have test coverage for both states:\n"

      missing_coverage.each do |item|
        message << "- **#{item[:feature]}**: Missing tests for #{item[:missing].join(' and ')}"

        if item[:enabled_specs].any?
          message << "  - ✅ Found enabled tests in: #{item[:enabled_specs].take(2).join(', ')}"
        end
        if item[:disabled_specs].any?
          message << "  - ✅ Found disabled tests in: #{item[:disabled_specs].take(2).join(', ')}"
        end
      end

      message << "\n**How to fix:**"
      message << 'Each feature toggle must be tested in both enabled and disabled states using stubs:'
      message << '```ruby'
      message << '# For enabled state:'
      message << "allow(Flipper).to receive(:enabled?).with(:#{missing_coverage.first[:feature]}).and_return(true)"
      message << '# For disabled state:'
      message << "allow(Flipper).to receive(:enabled?).with(:#{missing_coverage.first[:feature]}).and_return(false)"
      message << '```'
      message << "\nAlternatively, use the shared examples:"
      message << '```ruby'
      message << "it_behaves_like 'feature toggle behavior', :#{missing_coverage.first[:feature]}"
      message << '```'

      message.join("\n")
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

          output = `grep -r -l -E "#{pattern}" #{dir} --include=*.rb 2>/dev/null`
          return true if $CHILD_STATUS.success? && !output.strip.empty?
        end
      end

      false
    end
  end

  class SidekiqEnterpriseGaurantor
    def run
      return Result.error(error_message) if enterprise_remote_removed?

      Result.success('Sidekiq Enterprise is preserved.')
    end

    private

    def enterprise_remote_removed?
      gemfile_diff.include?('-  remote: https://enterprise.contribsys.com/')
    end

    def error_message
      <<~EMSG
        You've removed Sidekiq Enterprise from the gemfile!  You must restore it before merging this PR.

        More details about Sidekiq Enterprise can be found in the [README](https://github.com/department-of-veterans-affairs/vets-api/blob/master/README.md).
      EMSG
    end

    def gemfile_diff
      `git diff #{BASE_SHA}...#{HEAD_SHA} -- Gemfile.lock`
    end
  end

  if $PROGRAM_NAME == __FILE__
    require 'minitest/autorun'

    class ChangeLimiterTest < MiniTest::Test
      def test_rubocop
        assert system('rubocop --format simple')
      end

      # TODO: Remove dummy test
      def test_recommended_pr_size
        assert_equal ChangeLimiter::PR_SIZE[:recommended], 200
      end
    end
  end
end

if $PROGRAM_NAME != __FILE__
  VSPDanger::Runner.run.each do |result|
    case result.severity
    when VSPDanger::Result::ERROR
      failure result.message
    when VSPDanger::Result::WARNING
      warn result.message
    end
  end
end
