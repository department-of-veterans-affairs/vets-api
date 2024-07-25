# frozen_string_literal: true

module DependentsHelper
  def still_pending(decision, award_event_id)
    decision[:award_event_id] == award_event_id &&
      Time.zone.parse(decision[:award_effective_date]) > Time.zone.now
  end

  def upcoming_removals(decisions)
    decisions.transform_values do |decs|
      decs.filter { |dec| %w[T18 SCHATTT].include?(dec[:dependency_decision_type]) }
          .max { |a, b| a[:award_effective_date] <=> b[:award_effective_date] }
    end
  end

  def dependent_benefit_types(decisions)
    decisions.transform_values do |decs|
      dec = decs.find { |d| %w[EMC SCHATTB].include?(d[:dependency_decision_type]) }
      dec && dec[:dependency_status_type_description]&.gsub(/\s+/, ' ')
    end
  end

  def current_and_pending_decisions(diaries)
    # Filter by eligible minor child or school attendance types and if they are the current or future decisions
    decisions = dependency_decisions(diaries)
                .filter do |dec|
      date = Time.zone.parse(dec[:award_effective_date])
      (%w[EMC SCHATTB].include?(dec[:dependency_decision_type]) && date <= Time.zone.now) ||
        (%w[T18 SCHATTT].include?(dec[:dependency_decision_type]) && date > Time.zone.now)
    end

    decisions.group_by { |dec| dec[:person_id] }
             .transform_values do |decs|
      # get only most recent active decision and add back to array
      active =
        decs.filter do |dec|
          %w[EMC SCHATTB].include?(dec[:dependency_decision_type]) &&
            decs.any? { |d| still_pending(d, dec[:award_event_id]) }
        end
      most_recent = active.max { |a, b| a[:award_effective_date] <=> b[:award_effective_date] }
      # include future school attendance
      (decs.filter { |dec|
        %w[T18 SCHATTB SCHATTT].include?(dec[:dependency_decision_type])
      } + [most_recent]).compact
    end
  end

  def dependency_decisions(diaries)
    decisions = diaries && diaries[:dependency_decs]
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
        person[:upcoming_removal_date] = Time.zone.parse(upcoming_removal[:award_effective_date])
        person[:upcoming_removal_reason] = upcoming_removal[:dependency_decision_type_description].gsub(/\s+/, ' ')
      end

      person[:dependent_benefit_type] = dependent_benefit_types(decisions)[person[:ptcpnt_id]]
    end
  end
end
