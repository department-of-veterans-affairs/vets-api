# frozen_string_literal: true

require 'sidekiq'
require 'date'
# require './modules/vba_documents/spec/support/vba_document_fixtures' #remove me

module VBADocuments
  class ReportMonthlySubmissions
    include Sidekiq::Worker
    # include VBADocuments::Fixtures # remove me

    MONTHLY_COUNT_SQL = "
      select
        to_char(created_at, 'YYYYMM') as yyyymm,
        consumer_name,
        sum(case when status = 'error' then 1 else 0 end) as errored,
        sum(case when status = 'expired' then 1 else 0 end) as expired,
        sum(case when status = 'pending' or status = 'uploaded' or
            status = 'received' or status = 'processing' then 1 else 0 end) as processing,
        sum(case when status = 'success' then 1 else 0 end) as success,
        sum(case when status = 'vbms' then 1 else 0 end) as vbms,
        count(*) as total
      from vba_documents_upload_submissions a
      where a.created_at >= $1 and a.created_at < $2
      group by to_char(created_at, 'YYYYMM'), a.consumer_name
      order by to_char(created_at, 'YYYYMM') asc, a.consumer_name asc
    "

    PROCESSING_SQL = "
      select a.consumer_name, a.guid, a.status, a.created_at, a.updated_at
      from vba_documents_upload_submissions a
      where a.status in ('uploaded','received', 'processing','pending')
      and   a.updated_at < $1
      order by a.consumer_name asc
    "

    SUCCESS_SQL = "
      select a.consumer_name, a.guid, a.status, a.created_at, a.updated_at
      from vba_documents_upload_submissions a
      where a.status = 'success'
      and   a.uploaded_pdf is not null
      and   a.updated_at < $1
      order by a.consumer_name asc
    "

    MAX_AVG_SQL = "
      select yyyy, mm,
        NULLIF(sum(max_pages)::integer,0) as max_pages, NULLIF(sum(avg_pages)::integer,0) as avg_pages,
        NULLIF(sum(max_size)::bigint,0) as max_size, NULLIF(sum(avg_size)::bigint,0) as avg_size
      from (
      ( select
        date_part('year', a.created_at)::integer as yyyy,
        date_part('month', a.created_at)::integer as mm,
        max((uploaded_pdf->>'total_pages')::integer) as max_pages,
        round(avg((uploaded_pdf->>'total_pages')::integer))::integer as avg_pages,
        0::bigint as max_size,
        0::bigint as avg_size
      from vba_documents_upload_submissions a
      where a.uploaded_pdf is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
      )
    union
      ( select
        date_part('year', a.created_at)::integer as yyyy,
        date_part('month', a.created_at)::integer as mm,
        0::integer as max_pages,
        0::integer as avg_pages,
        max((metadata->'size')::bigint) as max_size_bytes,
        round(avg((metadata->'size')::bigint))::bigint as avg_size_bytes
      from vba_documents_upload_submissions a
      where a.metadata->'size' is not null
      and   a.status != 'error'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
      )
    ) as max_avg
    group by 1,2
    order by 1 desc, 2 desc
    "

    MODE_SQL = "
    select yyyy, mm, NULLIF(sum(mode_pages)::integer,0) as mode_pages, NULLIF(sum(mode_size)::bigint,0) as mode_size
    from (
        ( select
          date_part('year', a.created_at)::integer as yyyy,
          date_part('month', a.created_at)::integer as mm,
          mode() within group (order by (uploaded_pdf->>'total_pages')::integer) as mode_pages,
          0::bigint as mode_size
        from vba_documents_upload_submissions a
        where a.uploaded_pdf is not null
        and   a.status != 'error'
        and   a.created_at < $1
        group by 1,2
        order by 1 desc, 2 desc
        limit 12 )
      union
        ( select
            date_part('year', a.created_at)::integer as yyyy,
            date_part('month', a.created_at)::integer as mm,
            0::integer as mode_pages,
            mode() within group (order by (metadata->>'size')::bigint) as mode_size
          from vba_documents_upload_submissions a
          where a.metadata is not null
          and   a.status != 'error'
          and   a.created_at < $1
          group by 1,2
          order by 1 desc, 2 desc
          limit 12
        )
    ) as mode_results
    group by 1,2
    order by 1 desc, 2 desc
    "

    MEDIAN_SQL = "
      select NULLIF(sum(median_pages),0) as median_pages, NULLIF(sum(median_size),0) as median_size
      from (
        (select (uploaded_pdf->>'total_pages')::integer as median_pages, 0::bigint as median_size
        from vba_documents_upload_submissions a
        where a.uploaded_pdf is not null
        and   a.status != 'error'
        and   to_char(a.created_at,'yyyymm') = $1
        order by (uploaded_pdf->>'total_pages')::bigint
        offset (select count(*) from vba_documents_upload_submissions
        where uploaded_pdf is not null
        and   status != 'error'
        and   to_char(created_at,'yyyymm') = $1)/2
        limit 1)
        UNION
        (select 0::integer as median_pages, (metadata->>'size')::bigint as median_size
        from vba_documents_upload_submissions a
        where a.metadata is not null
        and   a.status != 'error'
        and   to_char(a.created_at,'yyyymm') = $1
        order by (metadata->>'size')::bigint
        offset (select count(*) from vba_documents_upload_submissions
        where metadata->>'size' is not null
        and   status != 'error'
        and   to_char(created_at,'yyyymm') = $1)/2
        limit 1)
      ) as median_results
    "

    AVG_TIME_TO_VBMS_SQL = "
      select
      date_part('year', a.created_at)::integer as yyyy,
      date_part('month', a.created_at)::integer as mm,
      count(*) as count,
    	avg(date_part('epoch', a.updated_at)::bigint -
        date_part('epoch', a.created_at)::bigint)::integer as avg_time_secs
      from vba_documents_upload_submissions a
      where a.status = 'vbms'
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    "

    def perform
      if Settings.vba_documents.monthly_report
        # get reporting date ranges
        last_month_start = (Date.current - 1.month).beginning_of_month
        last_month_end = Date.current.beginning_of_month

        # leave for testing locally with fixtures
        # @monthly_counts = get_fixture_yml('monthly_report/monthly_counts.yml')
        # still_processing = get_fixture_yml('monthly_report/still_processing.yml')
        # still_success = get_fixture_yml('monthly_report/still_success.yml')
        # @avg_processing_time = get_fixture_yml('monthly_report/avg_processing_time.yml')
        # @monthly_mode = get_fixture_yml('monthly_report/mode.yml') # was monthly_mode_pages with median added
        # @monthly_max_avg = get_fixture_yml('monthly_report/max_avg.yml') #was monthly_max_avg_pages.yml

        # execute SQL for monthly counts
        @monthly_counts = run_sql(MONTHLY_COUNT_SQL, last_month_start, last_month_end)
        still_processing = run_sql(PROCESSING_SQL, last_month_start)
        still_success = run_sql(SUCCESS_SQL, last_month_start)
        @avg_processing_time = run_sql(AVG_TIME_TO_VBMS_SQL, last_month_end)
        @monthly_max_avg = run_sql(MAX_AVG_SQL, last_month_end)
        @monthly_mode = run_sql(MODE_SQL, last_month_end)
        get_median_results
        add_max_avg_mb
        final_monthly_results = join_monthly_results

        # build the monthly report and email it
        VBADocuments::MonthlyReportMailer.build(
          @monthly_counts, summary, still_processing, still_success,
          final_monthly_results, last_month_start, last_month_end
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
      @avg_processing_time.each_with_index do |base_row, idx|
        base_row['avg_time'] = seconds_to_hms(base_row['avg_time_secs'])
        base_row.merge!(@monthly_max_avg[idx]) if @monthly_max_avg[idx]
        base_row.merge!(@monthly_mode[idx]) if @monthly_mode[idx]
        ret << base_row
      end
      # File.open("final_monthly_results.yml", "w") { |file| file.write(ret.to_yaml) } #todo delete me
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
        zero_pad = ('0' + row['mm'].to_s)[-2..2]
        yyyymm = "#{row['yyyy']}#{zero_pad}"
        median = run_sql(MEDIAN_SQL, yyyymm)
        row['median_pages'] = median.first['median_pages']
        row['mode_size'] = bytes_to_megabytes(row['mode_size'])
        row['median_size'] = bytes_to_megabytes(median.first['median_size'])
      end
    end

    def run_sql(sql, *args)
      ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end
    end
  end
end
