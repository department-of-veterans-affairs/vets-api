# frozen_string_literal: true

module Scopes
  # rubocop:disable Metrics/ModuleLength
  module Form526SubmissionState
    extend ActiveSupport::Concern

    # rubocop:disable Metrics/BlockLength
    # DOCUMENTATION:
    # https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/disability/526ez/engineering_research/526_scopes.md
    included do
      scope :pending_backup, lambda {
        where(submitted_claim_id: nil, backup_submitted_claim_status: nil)
          .where.not(backup_submitted_claim_id: nil)
          .where.missing(:form526_submission_remediations)
          .where(arel_table[:created_at].gt(Form526Submission::MAX_PENDING_TIME.ago))
      }
      scope :in_process, lambda {
        where(submitted_claim_id: nil)
          .where(backup_submitted_claim_id: nil)
          .where(arel_table[:created_at].gt(Form526Submission::MAX_PENDING_TIME.ago))
          .where.not(id: remediated.pluck(:id))
          .where.not(id: with_exhausted_backup_jobs.pluck(:id))
      }

      scope :accepted_to_primary_path, lambda {
        lh = accepted_to_lighthouse_primary_path.pluck(:id)
        evss = accepted_to_evss_primary_path.pluck(:id)
        where(id: lh + evss)
      }
      scope :accepted_to_evss_primary_path, lambda {
        where.not(submitted_claim_id: nil)
             .and(Form526Submission.where(submit_endpoint: nil)
             .or(Form526Submission.where.not(submit_endpoint: 'claims_api')))
      }
      scope :accepted_to_backup_path, lambda {
        where.not(backup_submitted_claim_id: nil)
             .where(
               backup_submitted_claim_status: [
                 backup_submitted_claim_statuses[:accepted],
                 backup_submitted_claim_statuses[:paranoid_success]
               ]
             )
      }
      scope :rejected_from_backup_path, lambda {
        where.not(backup_submitted_claim_id: nil)
             .where(backup_submitted_claim_status: backup_submitted_claim_statuses[:rejected])
      }
      scope :accepted_to_lighthouse_primary_path, lambda {
        left_outer_joins(:form526_job_statuses).where.not(submitted_claim_id: nil)
                                               .where(submit_endpoint: 'claims_api', form526_job_statuses: {
                                                        job_class: 'PollForm526Pdf', status: 'success'
                                                      })
      }

      scope :remediated, lambda {
        ids = joins(
          "INNER JOIN (
            SELECT form526_submission_id, MAX(created_at) AS max_created_at
            FROM form526_submission_remediations
            GROUP BY form526_submission_id
          ) AS latest_remediations
          ON form526_submissions.id = latest_remediations.form526_submission_id"
        ).joins(
          "INNER JOIN form526_submission_remediations
          ON form526_submission_remediations.form526_submission_id = latest_remediations.form526_submission_id
          AND form526_submission_remediations.created_at = latest_remediations.max_created_at"
        ).where(
          form526_submission_remediations: { success: true }
        ).select(:id)
        where(id: ids) # HACK: allow clean scope joining. Could be removed in favor of Arel
      }

      scope :with_exhausted_primary_jobs, lambda {
        joins(:form526_job_statuses)
          .where(submitted_claim_id: nil)
          .where(form526_job_statuses: { job_class: 'SubmitForm526AllClaim' })
          .where(form526_job_statuses: { status: Form526JobStatus::FAILURE_STATUSES.values })
      }
      scope :with_exhausted_backup_jobs, lambda {
        joins(:form526_job_statuses)
          .where(backup_submitted_claim_id: nil)
          .where(form526_job_statuses: { job_class: 'BackupSubmission' })
          .where(form526_job_statuses: { status: Form526JobStatus::FAILURE_STATUSES.values })
      }

      # Documentation describing the purpose of 'paranoid success' and 'success by age'
      # https://github.com/department-of-veterans-affairs/va.gov-team/blob/master/products/disability/526ez/engineering_research/paranoid_success_submissions.md
      scope :paranoid_success_type, lambda {
        where.not(backup_submitted_claim_id: nil)
             .where(backup_submitted_claim_status: backup_submitted_claim_statuses[:paranoid_success])
             .where.not(id: success_by_age.pluck(:id))
      }
      scope :success_by_age, lambda {
        where.not(backup_submitted_claim_id: nil)
             .where(backup_submitted_claim_status: backup_submitted_claim_statuses[:paranoid_success])
             .where(arel_table[:created_at].lt(1.year.ago))
      }

      # using .pluck(:id) forces execution of subqueries, preventing PG timeouts
      scope :success_type, lambda {
        ps_ids = accepted_to_primary_path.pluck(:id)
        bs_ids = accepted_to_backup_path.pluck(:id)
        red_ids = remediated.pluck(:id)
        par_ids = paranoid_success.pluck(:id)
        age_ids = success_by_age.pluck(:id)
        where(id: ps_ids + bs_ids + red_ids + par_ids + age_ids)
      }
      scope :incomplete_type, lambda {
        proc_ids = in_process.pluck(:id)
        pend_ids = pending_backup.select(:id)
        where(id: proc_ids + pend_ids)
      }

      scope :failure_type, lambda {
        # filtering in stages avoids timeouts. see doc for more info
        allids = where(submitted_claim_id: nil).pluck(:id)
        filter1 = where(id: allids - accepted_to_primary_path.pluck(:id)).pluck(:id)
        filter2 = where(id: filter1 - accepted_to_backup_path.pluck(:id)).pluck(:id)
        filter3 = where(id: filter2 - remediated.pluck(:id)).pluck(:id)
        filter4 = where(id: filter3 - paranoid_success.pluck(:id)).pluck(:id)
        filter5 = where(id: filter4 - success_by_age.pluck(:id)).pluck(:id)
        filter_final = where(id: filter5 - incomplete_type.pluck(:id)).pluck(:id)

        where(id: filter_final, submitted_claim_id: nil)
      }
    end
    # rubocop:enable Metrics/BlockLength
  end
  # rubocop:enable Metrics/ModuleLength
end
