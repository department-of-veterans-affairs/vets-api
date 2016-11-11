# frozen_string_literal: true
class DisabilityClaimBaseSerializer < ActiveModel::Serializer
  attributes :id, :evss_id, :date_filed, :min_est_date, :max_est_date,
             :phase_change_date, :open, :waiver_submitted, :documents_needed,
             :development_letter_sent, :decision_letter_sent,
             :updated_at, :phase, :ever_phase_back, :current_phase_back,
             :requested_decision

  # Our IDs are not stable due to 24 hour expiration, use EVSS IDs for consistency
  # This can be removed if our IDs become stable
  def id
    object.evss_id
  end

  def date_filed
    date_from_string 'date'
  end

  def min_est_date
    date_from_string 'minEstClaimDate'
  end

  def max_est_date
    date_from_string 'maxEstClaimDate'
  end

  def phase_change_date
    date_from_string 'claimPhaseDates', 'phaseChangeDate'
  end

  def ever_phase_back
    object_data.dig 'claimPhaseDates', 'everPhaseBack'
  end

  def current_phase_back
    object_data.dig 'claimPhaseDates', 'currentPhaseBack'
  end

  def open
    object_data['claimCompleteDate'].blank?
  end

  # TODO: (CMJ) When we have time, rename to requested_decision for better consistency
  def waiver_submitted
    object.requested_decision || object_data['waiver5103Submitted']
  end

  def documents_needed
    bool_from_yes_no 'attentionNeeded'
  end

  def development_letter_sent
    bool_from_yes_no 'developmentLetterSent'
  end

  def decision_letter_sent
    bool_from_yes_no 'decisionNotificationSent'
  end

  def phase
    raise NotImplementedError, 'Subclass of DisabilityClaimBaseSerializer must implement phase method'
  end

  protected

  def with_object_data(*keys)
    val = object_data.dig(*keys)
    yield val if val.present?
  end

  def bool_from_yes_no(*keys)
    with_object_data(*keys) do |s|
      case s.downcase
      when 'yes' then true
      when 'no' then false
      else
        Rails.logger.error "Expected EVSS key '#{keys}' to be Yes/No. Got '#{s}'."
        nil
      end
    end
  end

  def date_from_string(*keys, format: '%m/%d/%Y')
    with_object_data(*keys) do |s|
      Date.strptime(s, format)
    end
  end

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

  def phase_from_keys(*keys)
    s = object_data.dig(*keys)&.downcase
    phase = PHASE_MAPPING[s]
    Rails.logger.error "Expected EVSS #{keys} to be a phase. Got '#{s}'." unless phase
    phase
  end

  # object_data mediates whether a class uses object.data or
  # object.list_data as the basis of serialization.
  def object_data
    raise NotImplementedError, 'Subclass of DisabilityClaimBaseSerializer must implement object_data method'
  end
end
