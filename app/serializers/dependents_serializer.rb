# frozen_string_literal: true

class DependentsSerializer < ActiveModel::Serializer
  type :dependents

  has_many :persons, each_serializer: DependentSerializer

  def id
    nil
  end

  def persons
    @persons = object[:persons].instance_of?(Hash) ? [object[:persons]] : object[:persons]

    @persons.each do |person|
      person[:upcoming_removal] = upcoming_removals[person[:ptcpntId]]
      person[:dependent_benefit_type] = upcoming_dependent_benefit_types[person[:ptcpntId]]
    end
  end

  private

  def upcoming_removals
    @upcoming_removals ||= current_and_pending_decisions.map do |_p, decs|
      decs.max do |a, b|
        a[:award_effective_date] <=> b[:award_effective_date]
      end
    end
  end

  def dependent_benefit_types
    @dependent_benefit_types ||= current_and_pending_decisions.map do |_person, decisions|
      dec = decisions.find do |d|
        %w[EMC SCHATTB].include?(d[:dependency_decision_type])
      end
      dec[:dependency_status_type_description].gsub(/\s+/, ' ')
    end
  end

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

  def dependency_decisions
    decisions = object[:diaries][:dependency_decs][:dependency_dec]
    decisions.is_a?(Hash) ? [decisions] : decisions
  end
end
