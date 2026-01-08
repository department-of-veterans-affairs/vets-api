# frozen_string_literal: true

require 'ostruct'
require 'open3'

require_relative 'lib/dangerfile/parameter_filtering_allowlist_checker'

module VSPDanger
  HEAD_SHA = ENV.fetch('GITHUB_HEAD_REF', '').empty? ? `git rev-parse --abbrev-ref HEAD`.chomp.freeze : "origin/#{ENV.fetch('GITHUB_HEAD_REF')}"
  BASE_SHA = ENV.fetch('GITHUB_BASE_REF', '').empty? ? 'origin/master' : "origin/#{ENV.fetch('GITHUB_BASE_REF')}"

  class Runner
    def self.run
      prepare_git

      [
        SidekiqEnterpriseGuarantor.new.run,
        ChangeLimiter.new.run,
        MigrationIsolator.new.run,
        CodeownersCheck.new.run,
        GemfileLockPlatformChecker.new.run,
        ::Dangerfile::ParameterFilteringAllowlistChecker.new(base_sha: BASE_SHA, head_sha: HEAD_SHA).run
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
      modules/*/spec/**/*.rb spec/**/*.rb modules/*/docs/**/*.yaml modules/*/docs/**/*.yml modules/*/app/docs/**/*.yaml
      modules/*/app/docs/**/*.yml
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
        This PR changes `#{lines_changed}` lines of code (not counting whitespace/newlines, comments, or test files).

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
        This PR changes `#{lines_changed}` lines of code (not counting whitespace/newlines, comments, or test files).

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
                            @department-of-veterans-affairs/mobile-api-team]

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
    # Pre-compile regex patterns for performance
    DB_PATTERN = Regexp.union(DB_PATHS).freeze
    SEEDS_PATTERN = Regexp.union(SEEDS_PATHS).freeze
    # Allowed app file patterns when migrations are present
    # Based on strong_migrations best practices
    ALLOWED_APP_PATTERNS = [
      %r{spec/.+_spec\.rb$}, # Test files
      %r{modules/.+/spec/.+_spec\.rb$}, # Module test files
      %r{spec/factories/.+\.rb$}, # Factory changes
      %r{modules/.+/spec/factories/.+\.rb$} # Module factory changes
    ].freeze

    def run
      return Result.success('All set.') unless db_files.any?

      # Check for column removal without ignored_columns
      return Result.warn(column_removal_warning) if migration_removes_columns? && !ignored_columns_in_models?

      disallowed_files = app_files.reject { |file| allowed_app_file?(file) }

      return Result.error(error_message(disallowed_files)) if disallowed_files.any?
      return Result.warn(warning_message) if app_files.any?

      Result.success('All set.')
    end

    private

    def migration_removes_columns?
      # Use git grep for efficiency - searches without reading entire files
      return false if migration_files.empty?

      # Validate file paths for security
      validated_files = validate_file_paths(migration_files)
      return false if validated_files.empty?

      # Check all migration files at once with git grep
      # Use Open3 for secure command execution
      migration_pattern = 'remove_column|remove_columns|drop_column'
      cmd = ['git', 'grep', '-l', migration_pattern, '--'] + validated_files
      stdout, _stderr, status = Open3.capture3(*cmd)

      status.success? && !stdout.strip.empty?
    end

    def ignored_columns_in_models?
      model_files = app_files.grep(%r{app/models/.+\.rb$})

      return false if model_files.empty?

      # Validate file paths for security
      validated_files = validate_file_paths(model_files)
      return false if validated_files.empty?

      # Check all model files at once with git grep
      # Use Open3 for secure command execution
      cmd = ['git', 'grep', '-l', 'ignored_columns', '--'] + validated_files
      stdout, _stderr, status = Open3.capture3(*cmd)

      status.success? && !stdout.strip.empty?
    end

    def validate_file_paths(file_list)
      # Validate that file paths are safe and within repo
      file_list.select do |file|
        # Ensure no path traversal attempts
        !file.include?('..') &&
          # Ensure no absolute paths
          !file.start_with?('/') &&
          # Ensure no null bytes or special chars that could break commands
          !file.match?(/[\x00-\x1f]/) &&
          # Ensure file is within expected directories
          file.match?(%r{^(app|db|lib|spec|modules|config)/})
      end
    end

    def migration_files
      db_files.grep(%r{db/migrate/.+\.rb$})
    end

    def column_removal_warning
      <<~EMSG
        ⚠️ **Column Removal Detected Without `ignored_columns`**

        This PR contains a migration that removes columns but doesn't include `ignored_columns` in any models.

        **Strong Migrations recommends a 3-step process:**
        1. **First PR:** Add `ignored_columns` to the model
        2. **Second PR:** Remove the column with `safety_assured`
        3. **Third PR:** Remove `ignored_columns` from the model

        **Example for step 1:**
        ```ruby
        class YourModel < ApplicationRecord
          self.ignored_columns += ["column_to_remove"]
        end
        ```

        **Why this matters:**
        - Active Record caches columns at runtime
        - Removing columns without ignoring them first can cause production errors
        - Rolling deployments may have servers with different code versions

        Consider splitting this into separate PRs following the Strong Migrations pattern.

        For more info:
        - [Strong Migrations - Removing a column](https://github.com/ankane/strong_migrations#removing-a-column)
        - [vets-api Database Migrations](https://depo-platform-documentation.scrollhelp.site/developer-docs/Vets-API-Database-Migrations.689832034.html)
      EMSG
    end

    def allowed_app_file?(file)
      ALLOWED_APP_PATTERNS.any? { |pattern| file.match?(pattern) }
    end

    def warning_message
      <<~EMSG
        This PR contains both migration and application code changes.

        The following files were modified alongside migrations:
        - #{app_files.join "\n- "}

        These changes appear to be test-related files that need updating for the migration.
        This is generally acceptable as tests need to validate the new schema.

        Please ensure these changes are necessary for the migration's safety.
        For more info:
        - [Strong Migrations Best Practices](https://github.com/ankane/strong_migrations#removing-a-column)
        - [vets-api Database Migrations](https://depo-platform-documentation.scrollhelp.site/developer-docs/Vets-API-Database-Migrations.689832034.html)
      EMSG
    end

    def error_message(disallowed_files)
      <<~EMSG
        This PR contains migrations with disallowed application code changes.

        <details>
          <summary>File Summary</summary>

          #### DB File(s)
          - #{db_files.join "\n- "}

          #### Disallowed App File(s)
          - #{disallowed_files.join "\n- "}

          #{(app_files - disallowed_files).any? ? "#### Allowed App File(s)\n- #{(app_files - disallowed_files).join "\n- "}" : ''}
        </details>

        **Allowed changes with migrations:**
        - Test files and factories (to validate the migration)
        - Strong migrations configuration

        **Not allowed:**
        - Model changes (including `ignored_columns` - these should be in a separate PR)
        - Controller changes
        - Service object changes
        - Background job changes
        - Other business logic changes

        These should be deployed separately to ensure backwards compatibility.

        For more info:
        - [Strong Migrations Best Practices](https://github.com/ankane/strong_migrations)
        - [vets-api Database Migrations](https://depo-platform-documentation.scrollhelp.site/developer-docs/Vets-API-Database-Migrations.689832034.html)
      EMSG
    end

    def app_files
      (files - db_files - seed_files).reject { |file| file == File.basename(__FILE__) }
    end

    def db_files
      files.grep(DB_PATTERN)
    end

    def seed_files
      files.grep(SEEDS_PATTERN)
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

  class SidekiqEnterpriseGuarantor
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
        You've removed Sidekiq Enterprise from the Gemfile!  You must restore it before merging this PR.

        More details about Sidekiq Enterprise can be found in the [README](https://github.com/department-of-veterans-affairs/vets-api/blob/master/README.md).
      EMSG
    end

    def gemfile_diff
      `git diff #{BASE_SHA}...#{HEAD_SHA} -- Gemfile.lock`
    end
  end

  if $PROGRAM_NAME == __FILE__
    require 'minitest/autorun'

    class ChangeLimiterTest < Minitest::Test
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
