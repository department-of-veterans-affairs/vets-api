# frozen_string_literal: true

module VSPDanger
  class Runner
    def self.run
      [
        ChangeLimiter.new.run,
        MigrationIsolator.new.run
      ]
    end
  end

  class ChangeLimiter
    EXCLUSIONS = %w[
      *.csv *.json *.tsv *.txt Gemfile.lock app/swagger modules/mobile/docs spec/fixtures/ spec/support/vcr_cassettes/
    ].freeze
    PR_SIZE = { recommended: 200, maximum: 500 }.freeze

    def run
      return error if lines_changed > PR_SIZE[:maximum]
      return warning if lines_changed > PR_SIZE[:recommended]

      info
    end

    private

    def error
      { severity: :error, message: error_message }
    end

    def error_message
      <<~EMSG
        Tooo many lines
      EMSG
    end

    def warning
      { severity: :warning, message: warning_message }
    end

    def warning_message
      <<~EMSG
        Little too many lines
      EMSG
    end

    def info
      { severity: :info, message: 'Good job' }
    end

    def lines_changed
      changes.sum(&:total_changes)
    end

    def changes
      `#{files_command}`.split("\n").map do |line|
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
      "git diff #{base_sha}...#{head_sha} --numstat -w --ignore-blank-lines -- . #{exclusions}"
    end

    def exclusions
      EXCLUSIONS.map { |exclusion| "':!#{exclusion}'" }.join ' '
    end

    def head_sha
      `git branch --show-current`.chomp
    end

    def base_sha
      # TODO: decide if it's better to get this info from Danger
      # show_branch = `git show-branch`.split "\n"
      # ancestors = show_branch.grep(/\*/)
      # commits_excluding_current = ancestors.grep_v(/#{head_sha}/)
      # nearest_ancestor = commits_excluding_current.first
      # matched_branch_name = nearest_ancestor.match(/\[(.*)\]/)
      # matched_branch_name.captures.first
      'master'
    end
  end

  class MigrationIsolator
    def run
      return error if files.any? { |file| file.include? 'db/' } && !files.all? { |file| file.include? 'db/' }

      info
    end

    private

    def error
      { severity: :error, message: error_message }
    end

    def error_message
      <<~EMSG
        db/ no no
      EMSG
    end

    def info
      { severity: :info, message: 'Good job' }
    end

    def files
      `git diff #{base_sha}...#{head_sha} --name-only`.split("\n")
    end

    def head_sha
      `git branch --show-current`.chomp
    end

    def base_sha
      'master'
    end
  end

  if $PROGRAM_NAME == __FILE__
    require 'minitest/autorun'

    class ChangeLimiterTest < MiniTest::Test
      def test_rubocop
        assert system("rubocop #{__FILE__} --format simple --except Naming/FileName")
      end

      # TODO: Remove dummy test
      def test_recommended_pr_size
        assert_equal ChangeLimiter::PR_SIZE[:recommended], 200
      end
    end
  end
end

if $PROGRAM_NAME != __FILE__
  VSPDanger::Runner.run.each do |output|
    case output[:severity]
    when :error
      fail output[:message] # rubocop:disable Style/SignalException
    when :warning
      warn output[:message]
    when :info
      message output[:message]
    end
  end
end
