# frozen_string_literal: true

class DependentsVerificationsSerializer < ActiveModel::Serializer
  type :dependency_decs

  attribute :dependency_verifications
  attribute :prompt_renewal
  attribute :upcoming_removals
  attribute :dependent_benefit_types

  def id
    nil
  end

  def dependency_verifications
    formatted_payload
  end

  def prompt_renewal
    diary_entries.any? do |diary_entry|
      diary_entry[:diary_lc_status_type] == 'PEND' &&
        diary_entry[:diary_reason_type] == '24' &&
        diary_entry[:diary_due_date] < Time.zone.now + 7.years
    end
  end

  def upcoming_removals
    current_and_pending_decisions
      .map do |_p, decs|
      decs.max do |a, b|
        a[:award_effective_date] <=> b[:award_effective_date]
      end
    end
  end

  def dependent_benefit_types
    current_and_pending_decisions.map do |_person, decisions|
      dec = decisions.find do |d|
        %w[EMC SCHATTB].include?(d[:dependency_decision_type])
      end
      dec[:dependency_status_type_description].gsub(/\s+/, ' ')
    end
  end

  private

  def current_and_pending_decisions
    return @current_and_pending_decisions unless @current_and_pending_decisions.nil?

    # Filter by eligible minor child or school attendance types and if they are the current or future decisions
    decisions = dependency_decisions
                .filter do |dec|
      (%w[EMC SCHATTB].include?(dec[:dependency_decision_type]) && dec[:award_effective_date] < Time.zone.now) ||
        (%w[T18 SCHATTT].include?(dec[:dependency_decision_type]) && dec[:award_effective_date] > Time.zone.now)
    end

    @current_and_pending_decisions = decisions.group_by { |dec| dec[:person_id] }
                                              .map do |_p, decs|
      # get only most recent active decision and add back to array
      most_recent = decs.filter { |dec| %w[EMC SCHATTB].include?(dec[:dependency_decision_type]) }
                        .max { |a, b| a[:award_effective_date] <=> b[:award_effective_date] }
      # include future school attendance
      decs.filter { |dec|
        %w[T18 SCHATTB SCHATTT].include?(dec[:dependency_decision_type])
      } + [most_recent]
    end
  end

  def formatted_payload
    dependency_decs = object[:dependency_decs]
    ensured_array = dependency_decs.instance_of?(Hash) ? [dependency_decs] : dependency_decs

    @formatted_payload ||= ensured_array.map { |hash| hash.except(:social_security_number) }
  end

  def dependency_decisions
    object[:dependency_decs].is_a?(Hash) ? [object[:dependency_decs]] : object[:dependency_decs]
  end

  def diary_entries
    object[:diaries].is_a?(Hash) ? [object[:diaries]] : object[:diaries]
  end
end
