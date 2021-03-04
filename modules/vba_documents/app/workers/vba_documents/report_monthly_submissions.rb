# frozen_string_literal: true

require 'sidekiq'
require 'date'

module VBADocuments
  class ReportMonthlySubmissions
    include Sidekiq::Worker
    attr_reader :monthly_counts

    MONTHLY_COUNT_SQL = %q(
      select
        to_char(created_at, 'YYYYMM') as yyyymm,
        consumer_name,
        sum(case when status = 'error' then 1 else 0 end) as errored,
        sum(case when status = 'expired' then 1 else 0 end) as expired,
        sum(case when status = 'uploaded' or
            status = 'received' or status = 'processing' then 1 else 0 end) as processing,
        sum(case when status = 'success' then 1 else 0 end) as success,
        sum(case when status = 'vbms' then 1 else 0 end) as vbms,
        count(*) as total
      from vba_documents_upload_submissions a
      where a.created_at >= $1 and a.created_at < $2
      group by to_char(created_at, 'YYYYMM'), a.consumer_name
      order by to_char(created_at, 'YYYYMM') asc, a.consumer_name asc
    )

    PROCESSING_SQL = %q(
      select a.consumer_name, a.guid, a.status, a.created_at, a.updated_at
      from vba_documents_upload_submissions a
      where a.status in ('uploaded','received', 'processing')
      and   a.updated_at < $1
      order by a.consumer_name asc
    )

    MAX_AVG_PAGES_SQL = %q(
      select
        date_part('year', a.created_at)::INTEGER as yyyy,
        date_part('month', a.created_at)::INTEGER as mm,
        max((uploaded_pdf->>'total_pages')::integer) as max_pages,
        round(avg((uploaded_pdf->>'total_pages')::integer))::integer as avg_pages
      from vba_documents_upload_submissions a
      where a.uploaded_pdf is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    )

    MODE_PAGES_SQL = %q(
      select
        date_part('year', a.created_at)::INTEGER as yyyy,
        date_part('month', a.created_at)::INTEGER as mm,
        mode() within group (order by (uploaded_pdf->>'total_pages')::integer) as mode_pages
      from vba_documents_upload_submissions a
      where a.uploaded_pdf is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    )

    MEDIAN_SQL = %Q(
      select (uploaded_pdf->>'total_pages')::integer as median_pages
      from vba_documents_upload_submissions a
      where a.uploaded_pdf is not null
      and   a.status != 'error'
      and   to_char(a.created_at,'yyyymm') = $1
      order by (uploaded_pdf->>'total_pages')::integer
      offset (select count(*) from vba_documents_upload_submissions
        where uploaded_pdf is not null
        and   status != 'error'
        and   to_char(created_at,'yyyymm') = $1)/2
      limit 1
    )

    AVG_TIME_TO_VBMS = %q(
      select
      date_part('year', a.created_at)::INTEGER as yyyy,
      date_part('month', a.created_at)::INTEGER as mm,
      count(*) as count,
    	avg(date_part('epoch', a.updated_at)::INTEGER -
        date_part('epoch', a.created_at)::INTEGER)::integer as avg_time_secs
      from vba_documents_upload_submissions a
      where a.status = 'vbms'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    )

    def perform
      if Settings.vba_documents.monthly_report.enabled
        # get reporting date ranges
        last_month_start = (Date.current - 1.month).beginning_of_month
        last_month_end = Date.current.beginning_of_month
        two_months_ago_start = (Date.current - 2.months).beginning_of_month

        # execute SQL for monthly counts
        if Settings.vba_documents.monthly_report.use_fixtures
          filepath = 'modules/vba_documents/spec/fixtures/monthly_report/'
          @monthly_counts = File.open("#{filepath}monthly_counts.yml", 'r') { |f| YAML.load(f) }
          still_processing = File.open("#{filepath}monthly_still_processing.yml", 'r') { |f| YAML.load(f) }
          @avg_processing_time = File.open("#{filepath}monthly_avg_times.yml", 'r') { |f| YAML.load(f) }
          @monthly_max_avg = File.open("#{filepath}monthly_max_avg_pages.yml", 'r') { |f| YAML.load(f) }
          @monthly_mode_pages = File.open("#{filepath}monthly_mode_pages.yml", 'r') { |f| YAML.load(f) }
          #  note: to create these use:
          #  File.open('monthly_counts.yml', 'w') { |f| YAML.dump(@monthly_counts, f) }
        else
          @monthly_counts = run_sql(MONTHLY_COUNT_SQL, last_month_start, last_month_end)
          still_processing = run_sql(PROCESSING_SQL, two_months_ago_start)
          @avg_processing_time = run_sql(AVG_TIME_TO_VBMS, last_month_start)
          @monthly_max_avg = run_sql(MAX_AVG_PAGES_SQL, last_month_start)
          @monthly_mode_pages = run_sql(MODE_PAGES_SQL, last_month_start)
        end

        get_median_monthly_pages
        monthly_averages_final = join_monthly_results

        # build the monthly report and email it
        VBADocuments::MonthlyReportMailer.build(
          @monthly_counts, summary, still_processing, monthly_averages_final,
          last_month_start, last_month_end, two_months_ago_start
        ).deliver_now
      end
    end

    private
    def seconds_to_hms(sec)
      '%02d:%02d:%02d' % [sec / 3600, sec / 60 % 60, sec % 60]
    end

    def join_monthly_results
      ret = []
      @avg_processing_time.each_with_index do |base_row, idx|
        base_row['avg_time'] = seconds_to_hms(base_row['avg_time_secs'])
        base_row.merge!(@monthly_max_avg[idx]) if @monthly_max_avg[idx]
        base_row.merge!(@monthly_mode_pages[idx]) if @monthly_mode_pages[idx]
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
    def get_median_monthly_pages
      @monthly_mode_pages.each do |row|
        zero_pad = ('0' + row['mm'].to_s)[-2..2]
        yyyymm = "#{row['yyyy']}#{zero_pad}"
        median = run_sql(MEDIAN_SQL, yyyymm)
        median_value = median.first ? median.first['median_pages'] : 'unknown'
        row['median_pages'] = median_value
      end
    end

    def run_sql(sql, *args)
      # leave for local testing
      if Settings.vba_documents.monthly_report.use_fixtures && args[0] =~ /\d{6}/
        return [{'median_pages' => 5}]
      end
      ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end
    end
  end
end
