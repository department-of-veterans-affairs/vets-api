# frozen_string_literal: true

require 'holidays'

# jobs no located under app/*
require 'lighthouse/benefits_intake/sidekiq/submission_status_job'

# @see https://crontab.guru/
# @see https://en.wikipedia.org/wiki/Cron
# @see https://github.com/sidekiq/sidekiq/wiki/Ent-Periodic-Jobs
PERIODIC_JOBS = lambda { |mgr| # rubocop:disable Metrics/BlockLength
  mgr.tz = ActiveSupport::TimeZone.new('America/New_York')

  # Runs at midnight every Tuesday
  mgr.register('0 0 * * 2', 'LoadAverageDaysForClaimCompletionJob')

  # Update HigherLevelReview statuses with their Central Mail status
  mgr.register('5 * * * *', 'AppealsApi::HigherLevelReviewUploadStatusBatch')

  # Update NoticeOfDisagreement statuses with their Central Mail status
  mgr.register('10 * * * *', 'AppealsApi::NoticeOfDisagreementUploadStatusBatch')

  # Update SupplementalClaim statuses with their Central Mail status
  mgr.register('15 * * * *', 'AppealsApi::SupplementalClaimUploadStatusBatch')

  # Remove PII from appeal records after they have been successfully processed by the VA
  mgr.register('45 0 * * *', 'AppealsApi::CleanUpPii')

  # Ensures that appeal evidence received "late" (after the appeal has reached "success") is submitted to Central Mail
  mgr.register('30 * * * *', 'AppealsApi::EvidenceSubmissionBackup')

  # Daily report of appeals submissions
  mgr.register('0 23 * * 1-5', 'AppealsApi::DecisionReviewReportDaily')

  # Daily report of appeals errors
  mgr.register('0 23 * * 1-5', 'AppealsApi::DailyErrorReport')

  # Daily report of all stuck appeals submissions
  mgr.register('0 8 * * 1-5', 'AppealsApi::DailyStuckRecordsReport')

  # Weekly report of appeals submissions
  mgr.register('0 23 * * 7', 'AppealsApi::DecisionReviewReportWeekly')

  # Weekly CSV report of errored appeal submissions
  mgr.register('0 5 * * 1', 'AppealsApi::WeeklyErrorReport')

  # Email a decision reviews stats report for the past month to configured recipients first of the month
  mgr.register('0 0 1 * *', 'AppealsApi::MonthlyStatsReport')

  # Checks status of Flipper features expected to be enabled and alerts to Slack if any are not enabled
  mgr.register('0 2,9,16 * * 1-5', 'AppealsApi::FlipperStatusAlert')

  # Update alternative Banners data every 5 minutes
  mgr.register('*/5 * * * *', 'Banners::UpdateAllJob')

  # Update static data cache
  mgr.register('0 0 * * *', 'Crm::TopicsDataJob')

  # Update Optionset data cache
  mgr.register('0 0 * * *', 'Crm::OptionsetDataJob')

  # Update Facilities data cache
  mgr.register('0 0 * * *', 'Crm::FacilitiesDataJob')

  # Update FormSubmissionAttempt status from Lighthouse Benefits Intake API
  mgr.register('0 0 * * *', 'BenefitsIntakeStatusJob')
  mgr.register('0 0 * * *', '::BenefitsIntake::SubmissionStatusJob')

  # Generate FormSubmissionAttempt rememdiation statistics from Lighthouse Benefits Intake API
  mgr.register('0 1 * * 1', 'BenefitsIntakeRemediationStatusJob')

  # Update Lighthouse526DocumentUpload statuses according to Lighthouse Benefits Documents service tracking
  mgr.register('15 * * * *', 'Lighthouse::Form526DocumentUploadPollingJob')

  # Updates status of FormSubmissions per call to Lighthouse Benefits Intake API
  mgr.register('0 3 * * *', 'Form526StatusPollingJob')

  # Checks all 'success' type submissions in LH to ensure they haven't changed
  mgr.register('0 2 * * 0', 'Form526ParanoidSuccessPollingJob')

  # Log a report of 526 submission processing for a given timebox
  mgr.register('5 4 * * 7', 'Form526SubmissionProcessingReportJob')

  # Log a snapshot of everything in a full failure type state
  mgr.register('5 * * * *', 'Form526FailureStateSnapshotJob')

  # Clear out processed 22-1990 applications that are older than 1 month
  mgr.register('0 0 * * *', 'EducationForm::DeleteOldApplications')

  # Checks in TUD users that weren't properly checked in.
  mgr.register('20 0 * * *', 'TestUserDashboard::DailyMaintenance')

  # Import income limit data CSVs from S3
  mgr.register('0 0 1 * *', 'IncomeLimits::GmtThresholdsImport')

  # Import income limit data CSVs from S3
  mgr.register('0 0 1 * *', 'IncomeLimits::StdCountyImport')

  # Import income limit data CSVs from S3
  mgr.register('0 0 1 * *', 'IncomeLimits::StdIncomeThresholdImport')

  # Import income limit data CSVs from S3
  mgr.register('0 0 1 * *', 'IncomeLimits::StdStateImport')

  # Import income limit data CSVs from S3
  mgr.register('0 0 1 * *', 'IncomeLimits::StdZipcodeImport')

  # Import facilities data CSV from S3 daily at 4:30pmET
  mgr.register('30 16 * * *', 'HCA::StdInstitutionImportJob')

  # Clear out EVSS disability claims that have not been updated in 24 hours
  mgr.register('0 2 * * *', 'EVSS::DeleteOldClaims')

  # Clear out old personal information logs
  mgr.register('20 2 * * *', 'DeleteOldPiiLogsJob')

  # TODO: Document this job
  mgr.register('0 3 * * MON-FRI', 'EducationForm::CreateDailySpoolFiles')
  mgr.register('0 3 * * MON-FRI', 'EducationForm::CreateDailyExcelFiles')

  # Deletes old, completed AsyncTransaction records
  mgr.register('0 3 * * *', 'DeleteOldTransactionsJob')

  # Send the daily report to VA stakeholders about Education Benefits submissions
  mgr.register('0 4 * * *', 'EducationForm::CreateDailyFiscalYearToDateReport')

  # Send the daily report to the call center about spool file submissions
  mgr.register('5 4 * * 1-5', 'EducationForm::CreateSpoolSubmissionsReport')

  # Send the daily 10203 report to the call center about spool file submissions
  mgr.register('35 4 * * 1-5', 'EducationForm::Create10203SpoolSubmissionsReport')

  # Gather account login statistics for statsd
  mgr.register('0 6 * * *', 'AccountLoginStatisticsJob')

  # TODO: Document this job
  mgr.register('0 6-18/6 * * *', 'EducationForm::Process10203Submissions')

  # Delete expired sessions
  mgr.register('0 7 * * *', 'SignIn::DeleteExpiredSessionsJob')

  # Log when a client or service account config contains an expired, expiring, or self-signed certificate
  mgr.register('0 4 * * *', 'SignIn::CertificateCheckerJob')

  # Updates Cypress files in vets-website with data from Google Analytics.
  mgr.register('0 12 3 * *', 'CypressViewportUpdater::UpdateCypressViewportsJob')

  # Weekly logs of maintenance windows
  mgr.register('0 13 * * 1', 'Mobile::V0::WeeklyMaintenanceWindowLogger')

  # Hourly slack alert of errored claim submissions
  mgr.register('0 * * * *', 'ClaimsApi::ReportHourlyUnsuccessfulSubmissions')

  # Weekly report of unsuccessful claims submissions
  mgr.register('15 23 * * *', 'ClaimsApi::ReportUnsuccessfulSubmissions')

  # Monthly report of submissions
  mgr.register('00 00 1 * *', 'ClaimsApi::ReportMonthlySubmissions')

  # Daily find POAs caching
  mgr.register('0 2 * * *', 'ClaimsApi::FindPoasJob')

  # TODO: Document this job
  mgr.register('30 2 * * *', 'Identity::UserAcceptableVerifiedCredentialTotalsJob')

  # TODO: Document these jobs
  mgr.register('0 16 * * *', 'VANotify::InProgressForms')
  mgr.register('0 1 * * *', 'VANotify::ClearStaleInProgressRemindersSent')
  mgr.register('0 * * * *', 'VANotify::InProgress1880Form')
  mgr.register('0 * * * *', 'PagerDuty::CacheGlobalDowntime')
  mgr.register('*/3 * * * *', 'PagerDuty::PollMaintenanceWindows')
  mgr.register('0 2 * * *', 'InProgressFormCleaner')
  # mgr.register('0 */4 * * *', 'MHV::AccountStatisticsJob')
  mgr.register('0 3 * * *', 'Form1095::New1095BsJob')
  mgr.register('0 4 * * *', 'Form1095::DeleteOld1095BsJob')
  mgr.register('0 2 * * *', 'Veteran::VSOReloader')
  mgr.register('15 2 * * *', 'Preneeds::DeleteOldUploads')
  mgr.register('* * * * *', 'ExternalServicesStatusJob')
  mgr.register('* * * * *', 'ExportBreakerStatus')
  mgr.register('0 0 * * *', 'Form1010cg::DeleteOldUploadsJob')
  mgr.register('0 1 * * *', 'TransactionalEmailAnalyticsJob')

  # Disable FeatureCleanerJob. https://github.com/department-of-veterans-affairs/va.gov-team/issues/53538
  # mgr.register('0 0 * * *', 'FeatureCleanerJob')

  # Request updated statuses for benefits intake submissions
  mgr.register('45 * * * *', 'VBADocuments::UploadStatusBatch')

  # Run VBADocuments::UploadProcessor for submissions that are stuck in uploaded status
  mgr.register('5 */2 * * *', 'VBADocuments::RunUnsuccessfulSubmissions')

  # Poll upload bucket for unprocessed uploads
  mgr.register('*/3 * * * *', 'VBADocuments::UploadScanner')

  # Clean up submitted documents from S3
  mgr.register('2-59/5 * * * *', 'VBADocuments::UploadRemover')

  # Daily/weekly report of unsuccessful benefits intake submissions
  mgr.register('0 0 * * 1-5', 'VBADocuments::ReportUnsuccessfulSubmissions')

  # Monthly report of benefits intake submissions
  mgr.register('0 2 1 * *', 'VBADocuments::ReportMonthlySubmissions')

  # Notifies slack channel if certain benefits intake uploads get stuck in Central Mail
  mgr.register('0 8,12,17 * * 1-5', 'VBADocuments::SlackInflightNotifier')

  # Notifies slack channel if Benefits Intake Uploads are stuck in the LH BI service before sending to central mail
  mgr.register('15 * * * *', 'VBADocuments::SlackStatusNotifier')

  # Checks status of Flipper features expected to be enabled and alerts to Slack if any are not enabled
  mgr.register('0 2,9,16 * * 1-5', 'VBADocuments::FlipperStatusAlert')

  # Rotates Lockbox/KMS record keys and _ciphertext fields every October 12th (when the KMS key auto-rotate)
  mgr.register('50 1 * * *', 'KmsKeyRotation::BatchInitiatorJob')

  # Updates veteran representatives address attributes (including lat, long, location, address fields, email address, phone number) # rubocop:disable Layout/LineLength
  mgr.register('0 3 * * *', 'Representatives::QueueUpdates')
  # Updates veteran organizations address attributes (including lat, long, location, address fields)
  mgr.register('0 3 * * *', 'Organizations::QueueUpdates')

  # Sends emails to power of attorney claimants whose request will expire in 30 days
  mgr.register('0 8 * * *', 'PowerOfAttorneyRequests::SendExpirationReminderEmailJob')

  # Sends emails to power of attorney claimants whose request has expired
  mgr.register('0 8 * * *', 'PowerOfAttorneyRequests::SendExpiredEmailJob')

  # Updates veteran service organization names
  mgr.register('0 5 * * *', 'Organizations::UpdateNames')

  # Clean SchemaContact::Validation records every night at midnight
  mgr.register('0 0 * * *', 'SchemaContract::DeleteValidationRecordsJob')

  # Every 15min job that sends missing Pega statuses to DataDog
  mgr.register('*/15 * * * *', 'IvcChampva::MissingFormStatusJob')

  # Every 15min job that syncs ARP's allowlist
  mgr.register('*/15 * * * *', 'AccreditedRepresentativePortal::AllowListSyncJob')

  # Engine version: Sync non-final DR SavedClaims to LH status
  mgr.register('10 */4 * * *', 'DecisionReviews::HlrStatusUpdaterJob')
  mgr.register('15 1-21/4 * * *', 'DecisionReviews::NodStatusUpdaterJob')
  mgr.register('30 2-22/4 * * *', 'DecisionReviews::ScStatusUpdaterJob')

  # Engine version: Clean SavedClaim records that are past delete date
  mgr.register('0 5 * * *', 'DecisionReviews::DeleteSavedClaimRecordsJob')

  # Engine version: Send Decision Review emails to Veteran for failed form/evidence submissions
  mgr.register('5 0 * * *', 'DecisionReviews::FailureNotificationEmailJob')

  # Daily 0000 hrs job for Vye: performs ingress of state from BDN & TIMS.
  mgr.register('15 00 * * 1-5', 'Vye::MidnightRun::IngressBdn')
  mgr.register('45 03 * * 1-5', 'Vye::MidnightRun::IngressTims')
  # Daily 0600 hrs job for Vye: activates ingressed state, and egresses the changes for the day.
  mgr.register('45 05 * * 1-5', 'Vye::DawnDash')
  # Daily 1900 job for Vye: clears deactivated BDNs every evening.
  mgr.register('00 19 * * 1-5', 'Vye::SundownSweep')

  # Daily cleanup of > 12 month old UserAction records
  mgr.register('45 3 * * *', 'UserActionsCleanupJob')

  # CST Daily job that deletes EvidenceSubmissions when their delete_date has been met
  mgr.register('0 6 * * *', 'Lighthouse::EvidenceSubmissions::DeleteEvidenceSubmissionRecordsJob')

  # Hourly job that updates Evidence Submission Records that were uploaded to Lighthouse and are in a PENDING status.
  mgr.register('0 * * * *', 'Lighthouse::EvidenceSubmissions::EvidenceSubmissionDocumentUploadPollingJob')

  # Daily cron job to send Failure Notification Emails to Veterans for their failed evidence submissions.
  mgr.register('5 0 * * *', 'Lighthouse::EvidenceSubmissions::FailureNotificationEmailJob')
}
