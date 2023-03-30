# frozen_string_literal: true

class TransactionalEmailAnalyticsJob
  include Sidekiq::Worker

  sidekiq_options(unique_for: 30.minutes, retry: false)

  def initialize
    unless FeatureFlipper.send_email?
      raise Common::Exceptions::ParameterMissing.new(
        'GovDelivery token or server',
        detail: 'It should be configured in settings.yml'
      )
    end
    if Settings.google_analytics.tracking_id.blank?
      raise Common::Exceptions::ParameterMissing.new(
        'Google Analytics tracking ID',
        detail: 'It should be configured in settings.yml'
      )
    end
    @tracker = Staccato.tracker(Settings.google_analytics.tracking_id)
    @time_range_start = 1445.minutes.ago
    @time_range_end = 5.minutes.ago
  end

  def perform
    page = 0
    loop do
      page += 1
      relevant_emails(page).each do |mailer, emails|
        emails.each do |email|
          eval_email(email, mailer)
        end
      end
      break if we_should_break?
    end
  end

  # mailers descendant of TransactionalEmailMailer
  # these are declared explicitly because `.descendants` doesn't play well with zeitwerk autoloading
  def self.mailers
    [
      StemApplicantConfirmationMailer,
      SchoolCertifyingOfficialsMailer,
      DirectDepositMailer,
      HCASubmissionFailureMailer,
      StemApplicantScoMailer,
      StemApplicantDenialMailer
    ]
  end

  private

  def we_should_break?
    Time.zone.parse(@all_emails.collection.last.created_at) < @time_range_start || @all_emails.collection.count < 50
  end

  def relevant_emails(page)
    @all_emails = govdelivery_client.email_messages.get(
      page:,
      sort_by: 'created_at',
      sort_order: 'DESC',
      page_size: 50
    )

    grouped_emails = TransactionalEmailAnalyticsJob.mailers.index_with { |_mailer| [] }

    @all_emails.collection.each do |email|
      created_at = Time.zone.parse(email.created_at)
      if created_at > @time_range_start && created_at <= @time_range_end && email.status == 'completed'
        TransactionalEmailMailer.descendants.each_with_object(grouped_emails) do |mailer, grouped|
          grouped[mailer] << email if mailer::SUBJECT == email.subject
        end
      end
    end
    grouped_emails
  end

  def govdelivery_client
    @govdelivery_client ||= GovDelivery::TMS::Client.new(
      Settings.govdelivery.token,
      api_root: "https://#{Settings.govdelivery.server}",
      logger:
    )
  end

  def eval_email(email, mailer)
    email.failed.get
    event_params = {
      category: 'email',
      non_interactive: true,
      campaign_name: mailer::GA_CAMPAIGN_NAME,
      campaign_medium: 'email',
      campaign_source: 'gov-delivery',
      document_title: email.subject,
      document_path: mailer::GA_DOCUMENT_PATH,
      label: mailer::GA_LABEL
    }
    @tracker.event(event_params.merge(action: 'completed'))
    @tracker.event(event_params.merge(action: 'failed')) if email.failed.collection.count.positive?
  end
end
