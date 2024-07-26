# frozen_string_literal: true

class EVSSClaimDetailSerializer
  include JSONAPI::Serializer
  extend EVSSClaimTimelineHelper
  extend EVSSClaimBaseHelper

  # Our IDs are not stable due to 24 hour expiration, use EVSS IDs for consistency
  # This can be removed if our IDs become stable
  set_id :evss_id
  set_type :evss_claims

  attribute :evss_id

  # Hide updated_at if we're bypassing the database like the services endpoint
  attribute :updated_at, if: proc { |object| !object.updated_at.nil? }

  attribute :contention_list do |object|
    object.data['contention_list']
  end

  attribute :va_representative do |object|
    va_rep = object.data['poa']
    va_rep = ActionView::Base.full_sanitizer.sanitize(va_rep)
    va_rep&.gsub(/&[^ ;]+;/, '')
  end

  attribute :events_timeline do |object|
    events_timeline(object)
  end

  attribute :phase do |object|
    status = object.data.dig('claim_phase_dates', 'latest_phase_type')
    phase_from_keys(status)
  end

  attribute :date_filed do |object|
    date_attr(object.data['date'])
  end

  attribute :phase_change_date do |object|
    date_attr(object.data.dig('claim_phase_dates', 'phase_change_date'))
  end

  attribute :min_est_date do |object|
    date_attr(object.data['min_est_claim_date'])
  end

  attribute :max_est_date do |object|
    date_attr(object.data['max_est_claim_date'])
  end

  attribute :development_letter_sent do |object|
    value = object.data['development_letter_sent']
    yes_no_attr(value, 'development_letter_sent')
  end

  attribute :decision_letter_sent do |object|
    value = object.data['decision_notification_sent']
    yes_no_attr(value, 'decision_notification_sent')
  end

  attribute :documents_needed do |object|
    value = object.data['attention_needed']
    yes_no_attr(value, 'attention_needed')
  end

  attribute :ever_phase_back do |object|
    object.data.dig('claim_phase_dates', 'ever_phase_back')
  end

  attribute :current_phase_back do |object|
    object.data.dig('claim_phase_dates', 'current_phase_back')
  end

  attribute :open do |object|
    object.data['claim_complete_date'].blank?
  end

  attribute :requested_decision do |object|
    object.requested_decision || object.data['waiver5103_submitted']
  end

  # TODO: (CMJ) Remove once front end is integrated
  attribute :waiver_submitted do |object|
    object.requested_decision || object.data['waiver5103_submitted']
  end

  attribute :claim_type do |object|
    object.data['status_type']
  end
end
