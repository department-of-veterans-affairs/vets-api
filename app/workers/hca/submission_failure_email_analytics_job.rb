# frozen_string_literal: true

module HCA
  class SubmissionFailureEmailAnalyticsJob
    include Sidekiq::Worker

    sidekiq_options(unique_for: 30.minutes, retry: false)

    def initialize
      Sentry::TagRainbows.tag

      unless FeatureFlipper.send_email?
        raise Common::Exceptions::ParameterMissing.new(
          'GovDelivery token or server',
          detail: 'It should be configured in settings.yml'
        )
      end
      if Settings.google_analytics_tracking_id.blank?
        raise Common::Exceptions::ParameterMissing.new(
          'Google Analytics tracking ID',
          detail: 'It should be configured in settings.yml'
        )
      end
      @tracker = Staccato.tracker(Settings.google_analytics_tracking_id)
      @time_range_start = 1445.minutes.ago
      @time_range_end = 5.minutes.ago
    end

    def perform
      page = 0
      loop do
        page += 1
        hca_emails(page).each do |email|
          eval_email(email)
        end
        break if we_should_break?
      end
    end

    private

    def we_should_break?
      Time.zone.parse(@all_emails.collection.last.created_at) < @time_range_start || @all_emails.collection.count < 50
    end

    def hca_emails(page)
      @all_emails = govdelivery_client.email_messages.get(
        page: page,
        sort_by: 'created_at',
        sort_order: 'DESC',
        page_size: 50
      )
      @all_emails.collection.select do |email|
        [HCASubmissionFailureMailer::SUBJECT].include?(email.subject) &&
          Time.zone.parse(email.created_at) > @time_range_start
      end
    end

    def govdelivery_client
      @govdelivery_client ||= GovDelivery::TMS::Client.new(
        Settings.govdelivery.token,
        api_root: "https://#{Settings.govdelivery.server}",
        logger: logger
      )
    end

    def eval_email(email)
      return if Time.zone.parse(email.created_at) > @time_range_end || email.status != 'completed'
      email.failed.get
      event_params = {
        category: 'email',
        non_interactive: true,
        campaign_name: 'hca-failure',
        campaign_medium: 'email',
        campaign_source: 'gov-delivery',
        document_title: email.subject,
        document_path: '/email/health-care/apply/application/introduction',
        label: 'hca--submission-failed'
      }
      @tracker.event(event_params.merge(action: 'completed'))
      @tracker.event(event_params.merge(action: 'failed')) if email.failed.collection.count.positive?
    end
  end
end
