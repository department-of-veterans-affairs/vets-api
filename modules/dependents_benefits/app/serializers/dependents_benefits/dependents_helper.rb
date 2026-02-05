# frozen_string_literal: true

require 'dependents_benefits/monitor'

module DependentsBenefits
  ##
  # Helper module for processing and filtering dependency decisions from BGS.
  # Provides utilities for parsing dates, filtering dependency events, and
  # determining upcoming removals and benefit types for veteran dependents.
  #
  module DependentsHelper
    # Dependency decision types that mark the start of a dependent's benefit eligibility
    # EMC = Eligible Minor Child
    # SCHATTB = School Attendance Begins
    START_EVENTS = %w[EMC SCHATTB].freeze

    # Dependency decision types that have a later start date (future events)
    # SCHATTB = School Attendance Begins
    LATER_START_EVENTS = %w[SCHATTB].freeze

    # Dependency decision types that mark the end of a dependent's benefit eligibility
    # T18 = Turns 18
    # SCHATTT = School Attendance Terminates
    END_EVENTS = %w[T18 SCHATTT].freeze

    # Combined events that occur in the future
    FUTURE_EVENTS = (LATER_START_EVENTS + END_EVENTS).freeze

    ##
    # Parses a date string into a Time object using the application's time zone.
    #
    # @param date_string [String, nil] The date string to parse
    # @return [Time, nil] Parsed time object or nil if input is blank
    #
    def parse_time(date_string)
      return if date_string.blank?

      Time.zone.parse(date_string.to_s)
    end

    ##
    # Comparator function for sorting decisions by award effective date.
    #
    # @param a [Hash] First decision with :award_effective_date
    # @param b [Hash] Second decision with :award_effective_date
    # @return [Integer] -1, 0, or 1 for sorting
    #
    def compare_by_effective_date(a, b)
      a[:award_effective_date] <=> b[:award_effective_date]
    end

    ##
    # Determines if a dependency decision's effective date is in the future.
    #
    # @param decision [Hash] The decision containing :award_effective_date
    # @return [Boolean] True if the effective date is after the current time
    #
    def in_future?(decision)
      parse_time(decision[:award_effective_date]) > Time.zone.now
    end

    ##
    # Checks if a decision is still pending (matches award event ID and is in the future).
    #
    # @param decision [Hash] The decision to check
    # @param award_event_id [String] The award event ID to match against
    # @return [Boolean] True if decision matches the event ID and is still pending
    #
    def still_pending?(decision, award_event_id)
      decision[:award_event_id] == award_event_id && in_future?(decision)
    end

    ##
    # Normalizes whitespace in a string by replacing consecutive whitespace with single spaces.
    #
    # @param str [String, nil] The string to normalize
    # @return [String, nil] String with normalized whitespace, or nil if input is nil
    #
    def trim_whitespace(str)
      str&.gsub(/\s+/, ' ')
    end

    ##
    # Filters decisions to only include removal events (END_EVENTS).
    # This is a helper method that filters by decision type only, not by date.
    # Returns decisions of type T18 (Turns 18) or SCHATTT (School Attendance Terminates).
    #
    # @param decisions [Array<Hash>] Array of dependency decisions to filter
    # @return [Array<Hash>] Decisions that match END_EVENTS types
    #
    def select_end_events(decisions)
      decisions.filter do |dec|
        END_EVENTS.include?(dec[:dependency_decision_type])
      end
    end

    ##
    # Extracts the most recent upcoming removal event for each person.
    # Filters decisions by END_EVENTS and returns the one with the latest effective date.
    #
    # @param decisions [Hash] Hash of person_id => array of decisions
    # @return [Hash] Hash of person_id => most recent end event decision
    #
    def upcoming_removals(decisions)
      decisions.transform_values do |decs|
        select_end_events(decs).max { |a, b| compare_by_effective_date(a, b) }
      end
    end

    ##
    # Determines the benefit type for each person based on their START_EVENTS decisions.
    # Returns the dependency status type description for the applicable decision.
    #
    # @param decisions [Hash] Hash of person_id => array of decisions
    # @return [Hash] Hash of person_id => benefit type description (or nil)
    #
    def dependent_benefit_types(decisions)
      decisions.transform_values do |decs|
        dec = decs.find { |d| START_EVENTS.include?(d[:dependency_decision_type]) }
        dec && trim_whitespace(dec[:dependency_status_type_description])
      end
    end

    ##
    # Filters dependency decisions to only include currently active or upcoming events.
    # Includes START_EVENTS that are not in the future (currently active) and
    # END_EVENTS that are in the future (upcoming removals).
    #
    # @param diaries [Hash] The diaries hash containing dependency_decs
    # @return [Array<Hash>] Filtered array of active/upcoming dependency decisions
    #
    def filter_active_dependency_decisions(diaries)
      dependency_decisions(diaries)
        .filter do |dec|
          (START_EVENTS.include?(dec[:dependency_decision_type]) && !in_future?(dec)) ||
            (END_EVENTS.include?(dec[:dependency_decision_type]) && in_future?(dec))
        end
    end

    ##
    # Gets the most recent active START_EVENTS decision that has a pending award.
    # Filters to START_EVENTS that have any decision still pending, then returns
    # the one with the latest effective date.
    #
    # @param decisions [Array<Hash>] Array of dependency decisions
    # @return [Hash, nil] The most recent active decision or nil if none found
    #
    def filter_last_active_decision(decisions)
      active = decisions.filter do |dec|
        START_EVENTS.include?(dec[:dependency_decision_type]) &&
          decisions.any? { |d| still_pending?(d, dec[:award_event_id]) }
      end
      active.max { |a, b| compare_by_effective_date(a, b) }
    end

    ##
    # Filters decisions to only include future events.
    # Includes school attendance begins (SCHATTB) and all END_EVENTS that
    # have effective dates in the future.
    #
    # @param decisions [Array<Hash>] Array of dependency decisions
    # @return [Array<Hash>] Decisions with FUTURE_EVENTS types and future dates
    #
    def filter_future_decisions(decisions)
      decisions.filter do |dec|
        FUTURE_EVENTS.include?(dec[:dependency_decision_type]) && in_future?(dec)
      end
    end

    ##
    # Combines future decisions with the most recent active decision.
    # Returns an array containing all future events plus the most recent
    # active decision (if one exists).
    #
    # @param decisions [Array<Hash>] Array of dependency decisions
    # @return [Array<Hash>] Combined array of future and most recent active decisions
    #
    def merge_most_recent_and_future_decisions(decisions)
      filter_future_decisions(decisions) + [filter_last_active_decision(decisions)].compact
    end

    ##
    # Processes diaries to extract current and pending decisions grouped by person.
    # Returns a hash mapping each person_id to their relevant decisions (most recent
    # active decision plus all future decisions).
    #
    # @param diaries [Hash] The diaries hash from BGS containing dependency_decs
    # @return [Hash] Hash of person_id => array of current/pending decisions
    #
    def current_and_pending_decisions(diaries)
      decisions = filter_active_dependency_decisions(diaries)

      decisions.group_by { |dec| dec[:person_id] }
               .transform_values { |decs| merge_most_recent_and_future_decisions(decs) }
    end

    ##
    # Extracts and normalizes dependency decisions from the diaries structure.
    # Handles both Hash and Array formats of dependency_decs, ensuring the return
    # value is always an Array (or nil if input is invalid).
    #
    # @param diaries [Hash, Object] The diaries object from BGS
    # @return [Array<Hash>, nil] Array of dependency decisions or nil if invalid
    def dependency_decisions(diaries)
      decisions = if diaries.is_a?(Hash)
                    diaries[:dependency_decs]
                  else
                    monitor.track_error_event(
                      "Diaries is not a hash! Diaries type: #{diaries.class.name}",
                      'dependents_benefits.dependency_decisions.invalid_diaries_type'
                    )
                    nil
                  end
      return if decisions.nil?

      decisions.is_a?(Hash) ? [decisions] : decisions
    end

    ##
    # Returns a monitor instance for tracking events and errors.
    #
    # @return [DependentsBenefits::Monitor] Monitor instance
    #
    def monitor
      @monitor ||= DependentsBenefits::Monitor.new
    end
  end
end
