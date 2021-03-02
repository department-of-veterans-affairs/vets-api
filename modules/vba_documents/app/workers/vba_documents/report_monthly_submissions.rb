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
        sum(case when status = 'error' then 1 else 0 end) as "errored",
        sum(case when status = 'expired' then 1 else 0 end) as "expired",
        sum(case when status = 'uploaded' or
            status = 'received' or status = 'processing' then 1 else 0 end) as "processing",
        sum(case when status = 'success' then 1 else 0 end) as "success",
        sum(case when status = 'vbms' then 1 else 0 end) as "vbms"
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

    AVG_TIME_TO_COMPLETE_OR_ERROR_SQL = %q(
      select
      date_part('year', a.created_at)::INTEGER as yyyy,
      date_part('month', a.created_at)::INTEGER as mm,
      count(*) as count,
      avg(a.updated_at - a.created_at) as avg_time
      from vba_documents_upload_submissions a
      where a.status in ('success', 'vbms')
      and   a.created_at < $1
      group by 1,2
      order by 1 desc, 2 desc
      limit 12
    )

    def perform
      if Settings.vba_documents.monthly_report_enabled
        # get reporting date ranges
        last_month_start = (Date.current - 1.months).beginning_of_month
        last_month_end = Date.current.beginning_of_month
        two_months_ago_start = (Date.current - 2.months).beginning_of_month

        # execute SQL for monthly counts
        @monthly_counts = run_sql(MONTHLY_COUNT_SQL, last_month_start, last_month_end)
        last_month_still_processing = run_sql(PROCESSING_SQL, two_months_ago_start)
        avg_processing_time = run_sql(AVG_TIME_TO_COMPLETE_OR_ERROR_SQL, last_month_start)
        avg_processing_time = format_avg_time(avg_processing_time) if avg_processing_time.size > 0

        # @monthly_counts = temp_monthly_counts
        # last_month_still_processing = temp_still_processing
        # avg_processing_time = format_avg_time(temp_avg_days)

        # build the monthly report and email it
        VBADocuments::MonthlyReportMailer.build(
            @monthly_counts, summary, last_month_still_processing, avg_processing_time,
            last_month_start, last_month_end, two_months_ago_start) #.deliver_now
      end
    end

    def format_avg_time(results)
      results.each_with_index do |row, i|
        # format the average time stripping of millis if they exist
        idx = row['avg_time'].index('.')
        results[i]['avg_time'] = row['avg_time'][0, idx] if idx
      end
      results
    end

    def temp_monthly_counts
      [{"yyyymm" => "202101", "consumer_name" => "eVETassist-all", "errored" => 12, "expired" => 10, "processing" => 0, "success" => 377, "vbms" => 600},
       {"yyyymm" => "202101", "consumer_name" => "eVETassist-LickingCountyOH", "errored" => 4, "expired" => 1, "processing" => 0, "success" => 42, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "eVETassist-MedinaCountyOH", "errored" => 10, "expired" => 1, "processing" => 0, "success" => 301, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "eVETassist-SummitCountyOH", "errored" => 6, "expired" => 3, "processing" => 0, "success" => 83, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "MicroPact", "errored" => 96, "expired" => 0, "processing" => 0, "success" => 1820, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "MicroPact-StateOfNY", "errored" => 12, "expired" => 0, "processing" => 0, "success" => 748, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "StJohnsCountyFlorida", "errored" => 6, "expired" => 0, "processing" => 0, "success" => 96, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "VAClaimHelperSimmonds", "errored" => 5, "expired" => 7, "processing" => 0, "success" => 193, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "VetPro", "errored" => 159, "expired" => 0, "processing" => 0, "success" => 10661, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "VetraSpec", "errored" => 929, "expired" => 47, "processing" => 0, "success" => 23658, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "VisProInfo4Vets", "errored" => 9, "expired" => 0, "processing" => 0, "success" => 64, "vbms" => 0},
       {"yyyymm" => "202101", "consumer_name" => "WashCoMCV", "errored" => 0, "expired" => 0, "processing" => 0, "success" => 67, "vbms" => 0}]
    end
    def temp_still_processing
      # this is the output in the console from the query. The dates are changed to strings here
      [{"consumer_name"=>"VetraSpec", "guid"=>"5dde5458-4e6c-45b0-9818-1da4e2e1f801", "status"=>"processing", "created_at"=>'2020-12-23 21:26:39 UTC', "updated_at"=>'2020-12-23 21:36:00 UTC'}, {"consumer_name"=>"VetraSpec", "guid"=>"91070a9f-bbff-469b-9f0f-6da9fe34c0a8", "status"=>"processing", "created_at"=>'2020-12-22 16:43:16 UTC', "updated_at"=>'2020-12-22 16:49:49 UTC'}]
    end

    def temp_avg_days
      [{"yyyy"=>2021, "mm"=>1, "count"=>173, "avg_time"=>"00:00:16.568015"}, {"yyyy"=>2020, "mm"=>12, "count"=>236, "avg_time"=>"09:50:11.049635"}, {"yyyy"=>2020, "mm"=>11, "count"=>351, "avg_time"=>"00:00:20.84956"}, {"yyyy"=>2020, "mm"=>10, "count"=>176, "avg_time"=>"00:00:15.543005"}, {"yyyy"=>2020, "mm"=>9, "count"=>51, "avg_time"=>"00:00:20.407578"}, {"yyyy"=>2020, "mm"=>8, "count"=>147, "avg_time"=>"00:13:22.855617"}, {"yyyy"=>2020, "mm"=>7, "count"=>7318, "avg_time"=>"00:04:31.928402"}, {"yyyy"=>2020, "mm"=>6, "count"=>278, "avg_time"=>"00:03:14.935802"}, {"yyyy"=>2020, "mm"=>5, "count"=>73, "avg_time"=>"00:00:54.224481"}, {"yyyy"=>2020, "mm"=>4, "count"=>100, "avg_time"=>"00:00:19.434822"}, {"yyyy"=>2020, "mm"=>3, "count"=>14, "avg_time"=>"00:01:13.174984"}, {"yyyy"=>2020, "mm"=>1, "count"=>2, "avg_time"=>"00:01:31"}]
    end

    def summary
      sum_hash = {'errored' => 0, 'expired' => 0, 'processing' => 0, 'success' => 0, 'vbms' => 0}
      @monthly_counts.each do |row|
        sum_hash['errored'] += row['errored']
        sum_hash['expired'] += row['expired']
        sum_hash['processing'] += row['processing']
        sum_hash['success'] += row['success']
        sum_hash['vbms'] += row['vbms']
      end
      sum_hash
    end

    #private

    def run_sql(sql, *args)
      ActiveRecord::Base.connection_pool.with_connection do |c|
        c.raw_connection.exec_params(sql, args).to_a
      end
    end
  end
end
