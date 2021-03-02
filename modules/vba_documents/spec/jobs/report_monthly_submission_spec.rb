# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBADocuments::ReportMonthlySubmissions, type: :job do

  let(:monthly_counts) do
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

  let(:still_processing) do
    [{"consumer_name"=>"VetraSpec", "guid"=>"5dde5458-4e6c-45b0-9818-1da4e2e1f801", "status"=>"processing", "created_at"=>'2020-12-23 21:26:39 UTC', "updated_at"=>'2020-12-23 21:36:00 UTC'}, {"consumer_name"=>"VetraSpec", "guid"=>"91070a9f-bbff-469b-9f0f-6da9fe34c0a8", "status"=>"processing", "created_at"=>'2020-12-22 16:43:16 UTC', "updated_at"=>'2020-12-22 16:49:49 UTC'}]
  end

  let(:avg_days) do
    [{"yyyy"=>2021, "mm"=>1, "count"=>173, "avg_time"=>"00:00:16.568015"}, {"yyyy"=>2020, "mm"=>12, "count"=>236, "avg_time"=>"09:50:11.049635"}, {"yyyy"=>2020, "mm"=>11, "count"=>351, "avg_time"=>"00:00:20.84956"}, {"yyyy"=>2020, "mm"=>10, "count"=>176, "avg_time"=>"00:00:15.543005"}, {"yyyy"=>2020, "mm"=>9, "count"=>51, "avg_time"=>"00:00:20.407578"}, {"yyyy"=>2020, "mm"=>8, "count"=>147, "avg_time"=>"00:13:22.855617"}, {"yyyy"=>2020, "mm"=>7, "count"=>7318, "avg_time"=>"00:04:31.928402"}, {"yyyy"=>2020, "mm"=>6, "count"=>278, "avg_time"=>"00:03:14.935802"}, {"yyyy"=>2020, "mm"=>5, "count"=>73, "avg_time"=>"00:00:54.224481"}, {"yyyy"=>2020, "mm"=>4, "count"=>100, "avg_time"=>"00:00:19.434822"}, {"yyyy"=>2020, "mm"=>3, "count"=>14, "avg_time"=>"00:01:13.174984"}, {"yyyy"=>2020, "mm"=>1, "count"=>2, "avg_time"=>"00:01:31"}]
  end

    it 'does some shizzle' do
      with_settings(Settings.vba_documents,
                    monthly_report_enabled: true) do
        job = described_class.new
        monthly_sql = VBADocuments::ReportMonthlySubmissions::MONTHLY_COUNT_SQL
        proc_sql = VBADocuments::ReportMonthlySubmissions::PROCESSING_SQL
        avg_sql = VBADocuments::ReportMonthlySubmissions::AVG_TIME_TO_COMPLETE_OR_ERROR_SQL

        allow(job).to receive(:run_sql) do |sql, args|
          rval = monthly_counts if sql.eql? monthly_sql
          rval = still_processing if sql.eql? proc_sql
          rval = avg_days if sql.eql? avg_sql
          rval
        end
        job.perform
        expect(job.monthly_counts).to eq(monthly_counts)
      end
    end
  end
end