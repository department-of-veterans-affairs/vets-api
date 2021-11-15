# frozen_string_literal: true

require 'sidekiq'
require 'date'
require './modules/vba_documents/lib/vba_documents/sql_support'

module VBADocuments
  class ReportMonthlySubmissions
    include Sidekiq::Worker
    extend VBADocuments::SQLSupport

    def perform
      if Settings.vba_documents.monthly_report
        # get reporting date ranges
        last_month_start = (Date.current - 1.month).beginning_of_month
        last_month_end = Date.current.beginning_of_month

        # execute SQL for monthly counts
        @monthly_counts = run_sql(SQLSupport::MONTHLY_COUNT_SQL, last_month_start, last_month_end)
        still_processing = run_sql(SQLSupport::PROCESSING_SQL, last_month_start)
        still_success = run_sql(SQLSupport::SUCCESS_SQL,
                                VBADocuments::UploadSubmission::VBMS_IMPLEMENTATION_DATE, last_month_start)
        @monthly_grouping = run_sql(SQLSupport::MONTHLY_GROUP_SQL, last_month_end)
        @monthly_max_avg = run_sql(SQLSupport::MAX_AVG_SQL, last_month_end)
        @monthly_mode = run_sql(SQLSupport::MODE_SQL, last_month_end)
        rolling_elapsed_times = rolling_status_times
        get_median_results
        add_max_avg_mb
        final_monthly_results = join_monthly_results

        # build the monthly report and email it
        VBADocuments::MonthlyReportMailer.build(
          @monthly_counts, summary, still_processing, still_success,
          final_monthly_results, rolling_elapsed_times, last_month_start, last_month_end
        ).deliver_now
      end
    end

    private

    # rubocop:disable Style/FormatStringToken
    def seconds_to_hms(sec)
      format('%02d:%02d:%02d', sec / 3600, sec / 60 % 60, sec % 60)
    end
    # rubocop:enable Style/FormatStringToken

    MEGABYTES = 1024.0 * 1024.0
    def bytes_to_megabytes(bytes)
      (bytes / MEGABYTES).round(2) unless bytes.nil? || bytes.zero?
    end

    def add_max_avg_mb
      @monthly_max_avg.map! do |e|
        h = { 'max_mb' => nil, 'avg_mb' => nil }
        h['max_mb'] = bytes_to_megabytes(e['max_size'])
        h['avg_mb'] = bytes_to_megabytes(e['avg_size'])
        e.merge!(h)
      end
    end

    def join_monthly_results
      ret = []
      @monthly_grouping.each_with_index do |base_row, idx|
        base_row.merge!(@monthly_max_avg[idx]) if @monthly_max_avg[idx]
        base_row.merge!(@monthly_mode[idx]) if @monthly_mode[idx]
        ret << base_row
      end
      ret
    end

    def summary
      sum_hash = { 'errored' => 0, 'expired' => 0, 'processing' => 0, 'success' => 0, 'vbms' => 0, 'total' => 0 }
      @monthly_counts.each do |row|
        sum_hash['errored'] += row['errored']
        sum_hash['expired'] += row['expired']
        sum_hash['processing'] += row['processing']
        sum_hash['success'] += row['success']
        sum_hash['vbms'] += row['vbms']
        sum_hash['total'] += (row['errored'] + row['expired'] + row['processing'] + row['success'] + row['vbms'])
      end
      sum_hash
    end

    # add the median pages to the modes hash
    def get_median_results
      @monthly_mode.each do |row|
        zero_pad = ("0#{row['mm']}")[-2..2]
        yyyymm = "#{row['yyyy']}#{zero_pad}"
        median = run_sql(SQLSupport::MEDIAN_SQL, yyyymm)
        row['median_pages'] = median.first['median_pages']
        row['mode_size'] = bytes_to_megabytes(row['mode_size'])
        row['median_size'] = bytes_to_megabytes(median.first['median_size'])
      end
    end

    def rolling_status_times
      results_set = []
      12.times do |ym|
        from = (ym + 1).months.ago.beginning_of_month
        to = (ym + 1).month.ago.end_of_month
        yyyymm = from.year.to_s + ("00#{from.month}").last(2)
        results = UploadSubmission.status_elapsed_times(from, to)
        break if results.empty?

        status_hash = reformat_rolling_times(results)
        month_data = { yyyymm => status_hash }
        get_elapsed_median(month_data)
        tbs = get_time_between_statuses(yyyymm)
        month_data[yyyymm] = month_data[yyyymm].merge!(tbs[yyyymm])
        fmt_keys = %w[min_secs max_secs avg_secs median_secs min_bt_status max_bt_status avg_bt_status]
        calc_times(month_data, fmt_keys)
        results_set << month_data
      end
      results_set
    end

    def reformat_rolling_times(results)
      results.each_with_object({}) do |k, hash|
        s = k['status']
        hash[s] = k.tap do |h|
          h.delete('status')
        end
      end
    end

    # {"202104"=>{"pending"=>{"min_secs"=>1, "max_secs"=>1282, "avg_secs"=>12, "rowcount"=>49692, "median_secs"=>6},
    #           "processing"=>{"min_secs"=>3, "max_secs"=>529500, "avg_secs"=>6571, "rowcount"=>41198, ...}
    # format all of the times in seconds to hh:mm:ss
    def calc_times(data, keys)
      data.each_value do |v|
        v.each_pair do |_key, t|
          keys.each do |k|
            t["#{k}_fmt"] = seconds_to_hms(t[k]) if t.key?(k)
          end
        end
      end
    end

    def get_elapsed_median(month_data)
      yyyymm = month_data.keys[0]
      month_data[yyyymm].each_pair do |status, data|
        median = run_sql(SQLSupport::MEDIAN_ELAPSED_TIME_SQL, yyyymm, status).first
        data.merge!(median)
      end
    end

    def get_time_between_statuses(yyyymm)
      sql = SQLSupport::MONTHLY_TIME_BETWEEN_STATUSES_SQL
      ret = { yyyymm => {} }
      ret[yyyymm].merge!({ 'pending2error' => run_sql(sql, yyyymm, 'pending', 'error').first })
      ret[yyyymm].merge!({ 'pending2success' => run_sql(sql, yyyymm, 'pending', 'success').first })
      ret[yyyymm].merge!({ 'pending2vbms' => run_sql(sql, yyyymm, 'pending', 'vbms').first })
      ret[yyyymm].merge!({ 'success2vbms' => run_sql(sql, yyyymm, 'success', 'vbms').first })
      ret
    end

    def run_sql(sql, *args)
      ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end
    end
  end
end
