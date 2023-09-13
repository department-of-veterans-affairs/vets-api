# frozen_string_literal: true

class EVSSClaimBaseSerializer < ActiveModel::Serializer
  def self.date_attr(*names, override_name: nil, format: '%m/%d/%Y')
    name = override_name || names.last
    define_method(name) do
      date = object_data.dig(*names)
      return unless date

      Date.strptime(date, format)
    end
  end

  def self.yes_no_attr(*names, override_name: nil)
    name = override_name || names.last
    define_method(name) do
      s = object_data.dig(*names)
      return unless s

      case s.downcase
      when 'yes' then true
      when 'no' then false
      else
        Rails.logger.error "Expected key EVSS '#{keys}' to be Yes/No. Got '#{s}'."
        nil
      end
    end
  end

  private_class_method :date_attr
  private_class_method :yes_no_attr

  attributes :id, :evss_id, :date_filed, :min_est_date, :max_est_date,
             :phase_change_date, :open, :waiver_submitted, :documents_needed,
             :development_letter_sent, :decision_letter_sent,
             :phase, :ever_phase_back, :current_phase_back,
             :requested_decision, :claim_type

  attribute :updated_at, unless: :updated_at_nil?

  type :evss_claims

  # Our IDs are not stable due to 24 hour expiration, use EVSS IDs for consistency
  # This can be removed if our IDs become stable
  def id
    object.evss_id
  end

  date_attr 'date', override_name: 'date_filed'
  date_attr 'claim_phase_dates', 'phase_change_date'
  date_attr 'min_est_claim_date', override_name: 'min_est_date'
  date_attr 'max_est_claim_date', override_name: 'max_est_date'

  yes_no_attr 'development_letter_sent'
  yes_no_attr 'decision_notification_sent', override_name: 'decision_letter_sent'
  yes_no_attr 'attention_needed', override_name: 'documents_needed'

  # Hide updated_at if we're bypassing the database like the services endpoint

  def updated_at_nil?
    object.updated_at.nil?
  end

  def ever_phase_back
    object_data.dig 'claim_phase_dates', 'ever_phase_back'
  end

  def current_phase_back
    object_data.dig 'claim_phase_dates', 'current_phase_back'
  end

  def open
    object_data['claim_complete_date'].blank?
  end

  def requested_decision
    object.requested_decision || object_data['waiver5103_submitted']
  end

  # TODO: (CMJ) Remove once front end is integrated
  def waiver_submitted
    requested_decision
  end

  def claim_type
    object_data['status_type']
  end

  def phase
    raise NotImplementedError, 'Subclass of EVSSClaimBaseSerializer must implement phase method'
  end

  protected

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

  def phase_from_keys(*)
    s = object_data.dig(*)&.downcase
    PHASE_MAPPING[s]
    # Rails.logger.error "Expected EVSS #{keys} to be a phase. Got '#{s}'." unless phase
  end

  # object_data mediates whether a class uses object.data or
  # object.list_data as the basis of serialization.
  def object_data
    raise NotImplementedError, 'Subclass of EVSSClaimBaseSerializer must implement object_data method'
  end
end
