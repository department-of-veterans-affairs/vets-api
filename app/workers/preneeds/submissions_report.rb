# frozen_string_literal: true

module Preneeds
  class SubmissionsReport
    include Sidekiq::Worker
    def perform(start_date = Time.zone.today - 7, end_date = Time.zone.today)
      submissions = PersonalInformationLog.where(error_class: 'PreneedsBurial').where('created_at > ?', start_date)
                                          .where('created_at < ?', end_date)

      failures = submissions.reject do |sub|
        sub.decoded_data['response_body'] =~ %r{<returnCode>0</returnCode>}
      end

      server_unavailable_count = failures.select do |sub|
        sub.decoded_data['response_body'] =~ /503 Service Unavailable/
      end.count

      error_persisting_count = failures.select do |sub|
        sub.decoded_data['response_body'] =~ /Error persisting PreNeedApplication/
      end.count

      PreneedsSubmissionsReportMailer.build(
        start_date: start_date.to_s,
        end_date: (Time.zone.parse(end_date.to_s) - 1).to_date.to_s,
        successes_count: submissions.count - failures.count,
        error_persisting_count: error_persisting_count,
        server_unavailable_count: server_unavailable_count,
        other_errors_count: failures.count - error_persisting_count - server_unavailable_count
      ).deliver_now
    end
  end
end
