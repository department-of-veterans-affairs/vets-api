# frozen_string_literal: true

module VBADocuments
  class MonthlyStatsGenerator
    def initialize(month:, year:)
      @month = month&.to_i
      @year = year&.to_i

      raise ArgumentError, 'Month and year not provided' if @month.nil? || @year.nil?
      raise ArgumentError, 'Month and year not valid' unless valid_month? && valid_year?
    end

    def generate_and_save_stats
      VBADocuments::MonthlyStat.find_or_create_by(month: @month, year: @year).update(stats:)
    end

    private

    def valid_month?
      (1..12).to_a.include?(@month)
    end

    def valid_year?
      /^2\d{3}$/.match(@year.to_s)
    end

    def stats
      {
        summary_stats:,
        consumer_stats:,
        page_count_stats:,
        upload_size_in_mb_stats:,
        status_elapsed_time_stats:
      }.deep_stringify_keys
    end

    def summary_stats
      records_count = records_in_date_range.size
      error_percent = (errored_records.size.to_f / records_count).round(2)

      {
        expired_count: expired_records.size,
        errored_count: errored_records.size,
        processing_count: processing_records.size,
        success_count: success_records.size,
        vbms_count: success_records.size,
        total: records_count,
        error_percent:
      }
    end

    # consider moving to scope on VBADocuments::UploadSubmission
    def expired_records
      @expired_records ||= records_in_date_range.where(status: 'expired')
    end

    def errored_records
      @error_records ||= records_in_date_range.where(status: 'error')
    end

    def processing_records
      statuses = %w[pending uploaded received processing]
      @processing_records ||= records_in_date_range.where(status: statuses)
    end

    def success_records
      @success_records ||= records_in_date_range.where(status: 'success')
    end

    def vbms_records
      @vbms_records ||= records_in_date_range.where(status: 'vbms')
    end

    def consumer_stats
      consumer_names = records_in_date_range.pluck(:consumer_name)

      consumer_names.uniq.compact.sort.map do |consumer|
        errored_count = errored_records.for_consumer(consumer).count
        total = records_in_date_range.for_consumer(consumer).count
        error_percent = (errored_count.to_f / total).round(2)

        {
          consumer_name: consumer,
          expired_count: expired_records.for_consumer(consumer).count,
          errored_count:,
          processing_count: processing_records.for_consumer(consumer).count,
          success_count: success_records.for_consumer(consumer).count,
          vbms_count: vbms_records.for_consumer(consumer).count,
          total:,
          error_percent:
        }
      end
    end

    def page_count_stats
      page_counts = records_in_date_range.where("uploaded_pdf->'total_pages' IS NOT NULL")
                                         .pluck(Arel.sql("uploaded_pdf->'total_pages'"))
                                         .map(&:to_i)
      {
        total: page_counts.sum,
        maximum: page_counts.max,
        average: calculate_average(page_counts),
        median: calculate_median(page_counts),
        mode: calculate_mode(page_counts)
      }
    end

    def upload_size_in_mb_stats
      upload_sizes_in_mb = records_in_date_range.where("metadata->'size' is not null")
                                                .pluck(Arel.sql("metadata->'size'"))
                                                .map(&:to_i)
                                                .map { |size| (size / (1024.0 * 1024.0)).round(2) }

      {
        maximum: upload_sizes_in_mb.max,
        average: calculate_average(upload_sizes_in_mb),
        median: calculate_median(upload_sizes_in_mb),
        mode: calculate_mode(upload_sizes_in_mb)
      }
    end

    def status_elapsed_time_stats
      {
        pending: status_elapsed_times('pending'),
        uploaded: status_elapsed_times('uploaded'),
        received: status_elapsed_times('received'),
        processing: status_elapsed_times('processing'),
        success: status_elapsed_times('success'),
        pending_to_error: status_transition_times('pending', 'error'),
        pending_to_success: status_transition_times('pending', 'success'),
        pending_to_vbms: status_transition_times('pending', 'vbms'),
        success_to_vbms: status_transition_times('success', 'vbms')
      }
    end

    def start_date
      @start_date ||= DateTime.new(@year, @month)
    end

    def end_date
      @end_date ||= start_date.end_of_month
    end

    def records_in_date_range
      @records_in_date_range ||= VBADocuments::UploadSubmission
                                 .where('created_at >= ? and created_at <= ?', start_date, end_date)
                                 .where.not(consumer_name: nil)
    end

    def calculate_average(array)
      return nil if array.empty?

      (array.sum.to_f / array.size).round(2)
    end

    def calculate_median(array)
      return nil if array.empty?
      return array[0] if array.size == 1

      midpoint = array.size / 2 # Intentional integer division
      array.size.even? ? (array.sort[midpoint - 1, 2].sum / 2.0).round(2) : array.sort[midpoint]
    end

    def calculate_mode(array)
      return nil if array.empty?

      tallied = array.tally
      top_pair = tallied.sort_by { |_, v| v }.last(2)

      if top_pair.size == 1
        top_pair[0][0]
      elsif top_pair[0][1] == top_pair[1][1]
        nil
      else
        top_pair[1][0]
      end
    end

    def status_elapsed_times(status)
      valid_records = records_in_date_range.where("metadata->'status'->?->'start' is not null", status)
                                           .where("metadata->'status'->?->'end' is not null", status)
      sanitized_keys = ActiveRecord::Base.sanitize_sql(
        "metadata->'status'->'#{status}'->'start', metadata->'status'->'#{status}'->'end'"
      )
      timings_in_seconds = valid_records.pluck(Arel.sql(sanitized_keys))
      elapsed_times = timings_in_seconds.map { |r| r[1] - r[0] }

      {
        total: elapsed_times.size,
        minimum: seconds_to_hms(elapsed_times.min),
        maximum: seconds_to_hms(elapsed_times.max),
        average: seconds_to_hms(calculate_average(elapsed_times)),
        median: seconds_to_hms(calculate_median(elapsed_times))
      }
    end

    def status_transition_times(from_status, to_status)
      valid_records = records_in_date_range.where("metadata->'status'->?->'start' is not null", from_status)
                                           .where("metadata->'status'->?->'start' is not null", to_status)
      sanitized_keys = ActiveRecord::Base.sanitize_sql(
        "metadata->'status'->'#{from_status}'->'start', metadata->'status'->'#{to_status}'->'start'"
      )
      timings_in_seconds = valid_records.pluck(Arel.sql(sanitized_keys))
      transition_times = timings_in_seconds.map { |r| r[1] - r[0] }

      {
        total: transition_times.size,
        minimum: seconds_to_hms(transition_times.min),
        maximum: seconds_to_hms(transition_times.max),
        average: seconds_to_hms(calculate_average(transition_times))
      }
    end

    def seconds_to_hms(total_seconds)
      return nil unless total_seconds

      seconds = total_seconds % 60
      minutes = (total_seconds / 60) % 60
      hours = total_seconds / (60 * 60)

      format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours:, minutes:, seconds:)
    end
  end
end
