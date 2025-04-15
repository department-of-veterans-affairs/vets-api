class AddFailureToBpdsSubmissionStatusEnum < ActiveRecord::Migration[7.2]
  def up
    add_enum_value :bpds_submission_status, 'failure'
  end

  def down
    # Retrieve list of all successful and failed submissions and attempts
    submissions = []
    # Uncomment after implementing the Bpds::Submission model
    # Bpds::Submission.pluck(:id, :latest_status)
    attempts = []
    # Uncomment after implementing the Bpds::SubmissionAttempt model
    # Bpds::SubmissionAttempt.pluck(:id, :status)

    # Drop the enum list and remove columns using the enum
    safety_assured do
      remove_column :bpds_submissions, :latest_status
      remove_column :bpds_submission_attempts, :status
      drop_enum :bpds_submission_status
    end

    # Recreate the enum list without the failure status and add the columns back
    create_enum :bpds_submission_status, ["pending", "submitted"]
    add_column :bpds_submissions, :latest_status, :bpds_submission_status, default: "pending"
    add_column :bpds_submission_attempts, :status, :bpds_submission_status, default: "pending"

    # Update the status of the submissions and attempts to nil if they were previously "failure"
    submissions.each do |submission|
      id = submission[0]
      status = submission[1]

      if status == 'failure'
        set_submission_status(id, nil)
      else
        set_submission_status(id, status)
      end
    end
    attempts.each do |attempt|
      id = attempt[0]
      status = attempt[1]

      if status == 'failure'
        set_attempt_status(id, nil)
      else
        set_attempt_status(id, status)
      end
    end
  end

  def set_submission_status(id, latest_status)
    return if latest_status == 'pending'

    # Uncomment after implementing the Bpds::Submission model
    # BPDS::Submission.find_by(id:)&.update(latest_status:)
  end

  def set_attempt_status(id, status)
    return if status == 'pending'

    # Uncomment after implementing the Bpds::SubmissionAttempt model
    # BPDS::SubmissionAttempt.find_by(id:)&.update(status:)
  end
end
