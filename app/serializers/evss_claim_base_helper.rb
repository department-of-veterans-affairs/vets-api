# frozen_string_literal: true

module EVSSClaimBaseHelper
  PHASE_MAPPING = {
    'claim received' => 1,
    'under review' => 2,
    'gathering of evidence' => 3,
    'review of evidence' => 4,
    'preparation for decision' => 5,
    'pending decision approval' => 6,
    'preparation for notification' => 7,
    'complete' => 8
  }.freeze

  def phase_from_keys(phase)
    PHASE_MAPPING[phase&.downcase]
  end

  def date_attr(date, format: '%m/%d/%Y')
    return unless date

    Date.strptime(date, format)
  end

  def yes_no_attr(value, *names)
    return unless value

    case value.downcase
    when 'yes' then true
    when 'no' then false
    else
      Rails.logger.error "Expected key EVSS '#{names.join('/')}' to be Yes/No. Got '#{value}'."
      nil
    end
  end
end
