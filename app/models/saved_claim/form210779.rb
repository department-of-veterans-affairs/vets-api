# frozen_string_literal: true

class SavedClaim::Form210779 < SavedClaim
  FORM = '21-0779'

  validates :form, presence: true

  def process_attachments!
    # Form 21-0779 does not support attachments in MVP
    # This form is completed by nursing home staff providing information
    # No supporting documents are collected as part of the form submission
    Lighthouse::SubmitBenefitsIntakeClaim.perform_async(id)
  end

  # SavedClaims require regional_office to be defined
  def regional_office
    [].freeze
  end

  # Required for Lighthouse Benefits Intake API submission
  # CMP = Compensation (for Aid and Attendance claims)
  def business_line
    'CMP'
  end

  def attachment_keys
    # Form 21-0779 does not support attachments in MVP
    [].freeze
  end

  private

  def veteran_name
    veteran_info = parsed_form['veteranInformation'] || {}
    first = veteran_info['first'].to_s
    middle = veteran_info['middle'].to_s
    last = veteran_info['last'].to_s

    [first, middle, last].reject(&:empty?).join(' ')
  rescue
    'Veteran'
  end
end

