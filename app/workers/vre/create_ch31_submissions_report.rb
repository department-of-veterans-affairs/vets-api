# frozen_string_literal: true

module VRE
  class CreateCh31SubmissionsReport
    require 'csv'
    include Sidekiq::Worker

    def perform(sidekiq_scheduler_args, run_date = nil)
      date = if run_date
               run_date
             else
               epoch = sidekiq_scheduler_args['scheduled_at']
               Time.zone.at(epoch).yesterday.strftime('%Y-%m-%d')
             end

      submitted_claims = get_claims_created_between(build_range(date))
      Ch31SubmissionsReportMailer.build(submitted_claims).deliver_now
    end

    private

    def build_range(report_date)
      zone = 'Eastern Time (US & Canada)'
      begin_time = ActiveSupport::TimeZone[zone].parse("#{report_date} 00:00:00")
      end_time = ActiveSupport::TimeZone[zone].parse("#{report_date} 23:59:59")
      begin_time..end_time
    end

    def get_claims_created_between(range)
      SavedClaim::VeteranReadinessEmploymentClaim.where(
        created_at: range
      ).sort_by { |claim| claim.parsed_form['veteranInformation']['regionalOffice'] }
    end
  end
end
