# frozen_string_literal: true

require_relative 'report_submission_statuses/s3_consumer'

module DisabilityCompensation
  class ReportSubmissionStatuses
    class << self
      def filters
        mods = constants(false).grep(/Filter\z/)
        mods.map { |mod| mod.to_s.underscore }
      end

      def define_filter(name, &)
        const_set(name, Module.new(&))
      end
    end

    define_filter(:BddFilter) do
      const_set(:NEEDLE, /"bddQualified"\s*:\s*true/)

      class << self
        def applies?(record)
          self::NEEDLE.match?(record.form_json)
        end
      end
    end

    include Sidekiq::Job

    sidekiq_options retry: false

    def perform(consumer_klass, filter_klass, now, ids)
      @filter_klass = filter_klass.constantize
      @now = UTC.at(now)
      @ids = ids

      consumer = consumer_klass.constantize.new(@filter_klass.name.underscore, @now)
      output = consumer.perform(each_submission)
      console_print output
    end

    private

    def each_submission # rubocop:disable Metrics/MethodLength
      Enumerator.new do |yielder|
        rel = Form526Submission.where(created_at: ..@now)
        rel.where!(id: @ids) if @ids.present?
        rel.preload!(:form526_job_statuses)

        count = 0
        each = rel.find_each(
          order: :desc, batch_size: BATCH_SIZE
        )

        each.with_index do |record, index|
          index < SUBMISSIONS_PER_DAY or
            break

          if (index % PROGRESS_LOGGING_CADENCE).zero?
            console_print "#{@filter_klass} -- #{index} / #{SUBMISSIONS_PER_DAY}"
            console_print "#{@filter_klass} -- count: #{count}"
          end

          @filter_klass.applies?(record) or
            next

          submission = serialize_submission(record)
          yielder << submission
          count += 1
        end
      end
    end

    def serialize_submission(record)
      {}.tap do |submission|
        job_statuses = record.form526_job_statuses.sort_by(&:updated_at)
        job_statuses.map! { |s| s.as_json(only: JOB_STATUS_ATTRS) }

        submission.merge!(record.as_json(only: SUBMISSION_ATTRS))
        submission.merge!('job_statuses' => job_statuses)
      end
    end

    def console_print(message)
      puts message unless Rails.env.test?
    end

    UTC = ActiveSupport::TimeZone['UTC']
    PROGRESS_LOGGING_CADENCE = 100
    SUBMISSIONS_PER_DAY = 3_000
    BATCH_SIZE = 100

    SUBMISSION_ATTRS = %i[
      user_uuid saved_claim_id submitted_claim_id workflow_complete
      created_at updated_at user_account_id backup_submitted_claim_id
      aasm_state submit_endpoint backup_submitted_claim_status
    ].freeze

    JOB_STATUS_ATTRS = %i[
      job_id job_class status updated_at
      error_class error_message bgjob_errors
    ].freeze
  end
end
