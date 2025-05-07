# frozen_string_literal: true

START_EVENTS = %w[EMC SCHATTB].freeze
LATER_START_EVENTS = %w[SCHATTB].freeze
END_EVENTS = %w[T18 SCHATTT].freeze
FUTURE_EVENTS = (LATER_START_EVENTS + END_EVENTS).freeze

module DependentsHelper
  def max_time(a, b)
    a[:award_effective_date] <=> b[:award_effective_date]
  end

  def in_future(decision)
    Time.zone.parse(decision[:award_effective_date].to_s) > Time.zone.now
  end

  def still_pending(decision, award_event_id)
    decision[:award_event_id] == award_event_id && in_future(decision)
  end

  def trim_whitespace(str)
    str&.gsub(/\s+/, ' ')
  end

  def upcoming_removals(decisions)
    decisions.transform_values do |decs|
      decs.filter { |dec| END_EVENTS.include?(dec[:dependency_decision_type]) }.max { |a, b| max_time(a, b) }
    end
  end

  def dependent_benefit_types(decisions)
    decisions.transform_values do |decs|
      dec = decs.find { |d| START_EVENTS.include?(d[:dependency_decision_type]) }
      dec && trim_whitespace(dec[:dependency_status_type_description])
    end
  end

  def current_and_pending_decisions(diaries)
    # Filter by eligible minor child or school attendance types and if they are the current or future decisions
    decisions = dependency_decisions(diaries)
                .filter do |dec|
      (START_EVENTS.include?(dec[:dependency_decision_type]) && !in_future(dec)) ||
        (END_EVENTS.include?(dec[:dependency_decision_type]) && in_future(dec))
    end

    decisions.group_by { |dec| dec[:person_id] }
             .transform_values do |decs|
      # get only most recent active decision and add back to array
      active =
        decs.filter do |dec|
          START_EVENTS.include?(dec[:dependency_decision_type]) &&
            decs.any? { |d| still_pending(d, dec[:award_event_id]) }
        end
      most_recent = active.max { |a, b| max_time(a, b) }
      # include all future events (including school attendance begins)
      (decs.filter do |dec|
        FUTURE_EVENTS.include?(dec[:dependency_decision_type]) && in_future(dec)
      end + [most_recent]).compact
    end
  end

  def dependency_decisions(diaries)
    decisions = if diaries.is_a?(Hash)
                  diaries[:dependency_decs]
                else
                  Rails.logger.warn('Diaries is not a hash! Diaries value: ', diaries)
                  nil
                end
    return if decisions.nil?

    decisions.is_a?(Hash) ? [decisions] : decisions
  end
end

class DependentsSerializer
  extend DependentsHelper
  include JSONAPI::Serializer

  set_id { '' }
  set_type :dependents

  attribute :persons do |object|
    next [object[:persons]] if object[:persons].instance_of?(Hash)

    arr = object[:persons].instance_of?(Hash) ? [object[:persons]] : object[:persons]
    diaries = object[:diaries]

    next arr if dependency_decisions(diaries).blank?

    decisions = current_and_pending_decisions(diaries)

    arr.each do |person|
      upcoming_removal = person[:upcoming_removal] = upcoming_removals(decisions)[person[:ptcpnt_id]]
      if upcoming_removal
        person[:upcoming_removal_date] = if upcoming_removal[:award_effective_date].present?
                                           Time.zone.parse(upcoming_removal[:award_effective_date]&.to_s)
                                         end
        person[:upcoming_removal_reason] = trim_whitespace(upcoming_removal[:dependency_decision_type_description])
      end

      person[:dependent_benefit_type] = dependent_benefit_types(decisions)[person[:ptcpnt_id]]
    end
  end
end
