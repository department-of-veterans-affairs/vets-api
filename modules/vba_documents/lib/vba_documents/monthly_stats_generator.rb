# frozen_string_literal: true

module VBADocuments
  class MonthlyStatsGenerator
    def initialize(month:, year:)
      @month = month&.to_i
      @year = year&.to_i
      @stats = {}

      raise ArgumentError, 'Month and year not provided' if @month.nil? || @year.nil?
      raise ArgumentError, 'Month and year not valid' unless valid_month? && valid_year?
    end

    def generate_and_save_stats
      generate_summary_stats
      generate_page_count_stats
      generate_upload_size_stats
      generate_status_timing_stats

      VBADocuments::MonthlyStat.find_or_create_by(month: @month, year: @year).update(stats: @stats)
    end

    private

    def valid_month?
      (1..12).to_a.include?(@month)
    end

    def valid_year?
      /^2\d{3}$/.match(@year.to_s)
    end

    # rubocop:disable Metrics/MethodLength
    def generate_summary_stats
      expired = by_status('expired')
      errored = by_status('error')
      processing = by_status(%w[pending uploaded received processing])
      success = by_status('success')
      vbms = by_status('vbms')
      all = records_in_date_range

      if all.count.zero?
        @stats['summary_stats'] = { 'expired_count' => 0, 'errored_count' => 0, 'processing_count' => 0,
                                    'success_count' => 0, 'vbms_count' => 0, 'total' => 0, 'error_percent' => 0 }
      else
        @stats['summary_stats'] = {
          'expired_count' => expired.count,
          'errored_count' => errored.count,
          'processing_count' => processing.count,
          'success_count' => success.count,
          'vbms_count' => vbms.count,
          'total' => all.count,
          'error_percent' => (errored.count.to_f / all.count).round(2)
        }
      end
      # rubocop:enable Metrics/MethodLength

      generate_consumer_stats(expired, errored, processing, success, vbms, all)
    end

    # rubocop:disable Metrics/ParameterLists
    def generate_consumer_stats(expired, errored, processing, success, vbms, all)
      @stats['consumer_stats'] = []

      all.pluck(:consumer_name).uniq.sort.each do |consumer|
        errored_count = errored.for_consumer(consumer).count
        total = all.for_consumer(consumer).count

        @stats['consumer_stats'] << {
          'consumer_name' => consumer,
          'expired_count' => expired.for_consumer(consumer).count,
          'errored_count' => errored_count,
          'processing_count' => processing.for_consumer(consumer).count,
          'success_count' => success.for_consumer(consumer).count,
          'vbms_count' => vbms.for_consumer(consumer).count,
          'total' => total,
          'error_percent' => (errored_count.to_f / total).round(2)
        }
      end
    end
    # rubocop:enable Metrics/ParameterLists

    def generate_page_count_stats
      page_counts = records_in_date_range.where("uploaded_pdf->'total_pages' is not null")
                                         .pluck(Arel.sql("uploaded_pdf->'total_pages'")).map(&:to_i)

      @stats['page_count_stats'] = {
        'total' => page_counts.sum,
        'maximum' => page_counts.max,
        'average' => calculate_average(page_counts),
        'median' => calculate_median(page_counts),
        'mode' => calculate_mode(page_counts)
      }
    end

    def generate_upload_size_stats
      upload_sizes_in_mb = records_in_date_range.where("metadata->'size' is not null")
                                                .pluck(Arel.sql("metadata->'size'"))
                                                .map(&:to_i).map { |size| (size / (1024.0 * 1024.0)).round(2) }

      @stats['upload_size_in_mb_stats'] = {
        'maximum' => upload_sizes_in_mb.max,
        'average' => calculate_average(upload_sizes_in_mb),
        'median' => calculate_median(upload_sizes_in_mb),
        'mode' => calculate_mode(upload_sizes_in_mb)
      }
    end

    def generate_status_timing_stats
      @stats['status_elapsed_time_stats'] = {}

      statuses = %w[pending uploaded received processing success]
      statuses.each do |status|
        @stats['status_elapsed_time_stats'][status] = status_elapsed_times(status)
      end

      status_transitions = [
        { from: 'pending', to: 'error' },
        { from: 'pending', to: 'success' },
        { from: 'pending', to: 'vbms' },
        { from: 'success', to: 'vbms' }
      ]
      status_transitions.each do |transition|
        status = "#{transition[:from]}_to_#{transition[:to]}"
        @stats['status_elapsed_time_stats'][status] = status_transition_times(transition[:from], transition[:to])
      end
    end

    def by_status(status)
      records_in_date_range.where(status:)
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

      if elapsed_times.empty?
        { 'total' => 0, 'minimum' => nil, 'maximum' => nil, 'average' => nil, 'median' => nil }
      else
        {
          'total' => elapsed_times.size,
          'minimum' => seconds_to_hms(elapsed_times.min),
          'maximum' => seconds_to_hms(elapsed_times.max),
          'average' => seconds_to_hms(calculate_average(elapsed_times)),
          'median' => seconds_to_hms(calculate_median(elapsed_times))
        }
      end
    end

    def status_transition_times(from_status, to_status)
      valid_records = records_in_date_range.where("metadata->'status'->?->'start' is not null", from_status)
                                           .where("metadata->'status'->?->'start' is not null", to_status)
      sanitized_keys = ActiveRecord::Base.sanitize_sql(
        "metadata->'status'->'#{from_status}'->'start', metadata->'status'->'#{to_status}'->'start'"
      )
      timings_in_seconds = valid_records.pluck(Arel.sql(sanitized_keys))
      transition_times = timings_in_seconds.map { |r| r[1] - r[0] }

      if transition_times.empty?
        { 'total' => 0, 'minimum' => nil, 'maximum' => nil, 'average' => nil }
      else
        {
          'total' => transition_times.size,
          'minimum' => seconds_to_hms(transition_times.min),
          'maximum' => seconds_to_hms(transition_times.max),
          'average' => seconds_to_hms(calculate_average(transition_times))
        }
      end
    end

    def seconds_to_hms(total_seconds)
      seconds = total_seconds % 60
      minutes = (total_seconds / 60) % 60
      hours = total_seconds / (60 * 60)

      format('%<hours>02d:%<minutes>02d:%<seconds>02d', hours:, minutes:, seconds:)
    end
  end
end
