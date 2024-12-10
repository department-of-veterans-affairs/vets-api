# frozen_string_literal: true

class Form526SubmissionRemediation < ApplicationRecord
  belongs_to :form526_submission

  validates :lifecycle, presence: true, if: :new_or_changed?
  validate :validate_context_on_create_update
  validate :ensure_success_if_ignored_as_duplicate

  before_create :initialize_lifecycle

  enum :remediation_type, { manual: 0, ignored_as_duplicate: 1, email_notified: 2 }

  STATSD_KEY_PREFIX = 'form526_submission_remediation'

  def mark_as_unsuccessful(context)
    self.success = false
    if add_context_to_lifecycle(context)
      save!
      log_to_datadog(context)
    end
  end

  private

  def initialize_lifecycle
    self.lifecycle ||= []
  end

  def validate_context_on_create_update
    errors.add(:base, 'Context required for create/update actions') if lifecycle.empty? || lifecycle.last.blank?
  end

  def ensure_success_if_ignored_as_duplicate
    errors.add(:success, 'must be true if ignored as duplicate') if ignored_as_duplicate? && !success
  end

  def log_to_datadog(context)
    StatsD.increment("#{STATSD_KEY_PREFIX} marked as unsuccessful: #{context}")
  end

  def add_context_to_lifecycle(context)
    if context.is_a?(String) && context.strip.present?
      self.lifecycle << "#{Time.current.strftime('%Y-%m-%d %H:%M:%S')} -- #{context}"
      true
    else
      errors.add(:base, 'Context must be a non-empty string')
      false
    end
  end

  def new_or_changed?
    new_record? || changed?
  end
end
