# frozen_string_literal: true

module VSPDanger
  HEAD_SHA = `git rev-parse --abbrev-ref HEAD`.chomp.freeze
  BASE_SHA = 'origin/master'

  class Runner
    def self.run
      prepare_git

      [
        SidekiqEnterpriseGaurantor.new.run,
        ChangeLimiter.new.run,
        MigrationIsolator.new.run
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
      *.csv *.json *.tsv *.txt Gemfile.lock app/swagger modules/mobile/docs spec/fixtures/ spec/support/vcr_cassettes/
      modules/mobile/spec/support/vcr_cassettes/ db/seeds modules/vaos/app/docs
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
        [Code Review Guidelines FAQ](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/code_review_guidelines.md#faq).

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
      @changes ||= `#{files_command}`.split("\n").map do |line|
        insertions, deletions, file_name = line.split "\t"
        insertions = insertions.to_i
        deletions = deletions.to_i

        next if insertions.zero? && deletions.zero?   # Skip unchanged files
        next if insertions == '-' && deletions == '-' # Skip Binary files

        OpenStruct.new(
          total_changes: insertions + deletions,
          insertions: insertions,
          deletions: deletions,
          file_name: file_name
        )
      end.compact
    end

    def files_command
      "git diff #{BASE_SHA}...#{HEAD_SHA} --numstat -w --ignore-blank-lines -- . #{exclusions}"
    end

    def exclusions
      EXCLUSIONS.map { |exclusion| "':!#{exclusion}'" }.join ' '
    end
  end

  class MigrationIsolator
    def run
      if files.any? { |file| file.include? 'db/' } && !files.all? { |file| file.include? 'db/' }
        # one of the changed files was in 'db/' but not all of them
        return Result.error(error_message)
      end

      Result.success('All set.')
    end

    private

    def error_message
      <<~EMSG
        Modified files in `db/` should be the only files checked into this PR.

        <details>
          <summary>File Summary</summary>

          #### DB File(s)

          - #{db_files.join "\n- "}

          #### App File(s)

          - #{app_files.join "\n- "}
        </details>

        Database migrations do not run automatically with vets-api deployments. Application code must always be
        backwards compatible with the DB, both before and after migrations have been run. For more info:

        - [Guidance on Safe DB Migrations](https://github.com/ankane/strong_migrations#checks)
        - [`vets-api` Deployment Process](https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/platform/engineering/deployment.md)
      EMSG
    end

    def app_files
      files - db_files
    end

    def db_files
      files.select { |file| file.include? 'db/' }
    end

    def files
      @files ||= `git diff #{BASE_SHA}...#{HEAD_SHA} --name-only`.split("\n")
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
