# frozen_string_literal: true

class DependentsSerializer
  include JSONAPI::Serializer
  set_id { '' }
  set_type :dependents

  attribute :persons do |object|
    arr = object[:persons].instance_of?(Hash) ? [object[:persons]] : object[:persons]

    next arr if dependency_decisions.blank?

    arr.each do |person|
      upcoming_removal = person[:upcoming_removal] = upcoming_removals[person[:ptcpnt_id]]
      if upcoming_removal
        person[:upcoming_removal_date] = upcoming_removal[:award_effective_date]
        person[:upcoming_removal_reason] = upcoming_removal[:dependency_status_type_description].gsub(/\s+/, ' ')
      end

      person[:dependent_benefit_type] = dependent_benefit_types[person[:ptcpnt_id]]
    end
  end

  private

  def upcoming_removals
    @upcoming_removals ||= current_and_pending_decisions.transform_values do |decs|
      decs.filter { |dec| %w[T18 SCHATTT].include?(dec[:dependency_decision_type]) }
          .max { |a, b| a[:award_effective_date] <=> b[:award_effective_date] }
    end
  end

  def dependent_benefit_types
    @dependent_benefit_types ||= current_and_pending_decisions.transform_values do |decisions|
      dec = decisions.find { |d| %w[EMC SCHATTB].include?(d[:dependency_decision_type]) }
      dec[:dependency_status_type_description].gsub(/\s+/, ' ')
    end
  end

  def current_and_pending_decisions
    return @current_and_pending_decisions if @current_and_pending_decisions.present?

    # Filter by eligible minor child or school attendance types and if they are the current or future decisions
    decisions = dependency_decisions
                .filter do |dec|
      (%w[EMC SCHATTB].include?(dec[:dependency_decision_type]) && dec[:award_effective_date] < Time.zone.now) ||
        (%w[T18 SCHATTT].include?(dec[:dependency_decision_type]) && dec[:award_effective_date] > Time.zone.now)
    end

    @current_and_pending_decisions = decisions.group_by { |dec| dec[:person_id] }
                                              .transform_values do |decs|
      # get only most recent active decision and add back to array
      most_recent =
        decs.filter { |dec| %w[EMC SCHATTB].include?(dec[:dependency_decision_type]) }
            .max { |a, b| a[:award_effective_date] <=> b[:award_effective_date] }
      # include future school attendance
      (decs.filter { |dec|
        %w[T18 SCHATTB SCHATTT].include?(dec[:dependency_decision_type])
      } + [most_recent]).uniq
    end
  end

  def dependency_decisions
    decisions = object.dig(:diaries, :dependency_decs)
    return if decisions.nil?

    decisions.is_a?(Hash) ? [decisions] : decisions
  end
end
