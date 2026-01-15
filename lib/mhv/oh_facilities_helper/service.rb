# frozen_string_literal: true

module MHV
  module OhFacilitiesHelper
    class Service
      def initialize(user)
        super()
        @current_user = user
      end

      OH_FEATURE_TOGGLES = [
        # List of OH feature toggles to check
        :mhv_accelerated_delivery_allergies_enabled,
        :mhv_accelerated_delivery_care_notes_enabled,
        :mhv_accelerated_delivery_conditions_enabled,
        :mhv_accelerated_delivery_labs_and_tests_enabled,
        :mhv_accelerated_delivery_vital_signs_enabled,
        :mhv_secure_messaging_cerner_pilot,
        :mhv_medications_cerner_pilot
      ].freeze

      # Phase boundaries are INCLUSIVE - day -45 is the START of p1
      PHASES = {
        p0: -60, # Day -60: 60 days before migration
        p1: -45, # Day -45: 45 days before migration
        p2: -30, # Day -30: 30 days before migration
        p3: -5,  # Day -5: 5 days before migration
        p4: -2,  # Day -2: 2 days before migration
        p5: 0,   # Day 0: Migration day
        p6: 2,   # Day 2: 2 days after migration
        p7: 7    # Day 7: 7 days after migration
      }.freeze

      MIGRATION_STATUS = {
        not_started: 'NOT_STARTED', # Before p0 (>60 days before migration)
        active: 'ACTIVE',           # Between p0 and p7 (inclusive)
        complete: 'COMPLETE'        # After p7 (>7 days after migration)
      }.freeze

      def user_at_pretransitioned_oh_facility?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          pretransitioned_oh_facilities.include?(facility.to_s)
        end
      end

      def user_facility_ready_for_info_alert?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_ready_for_info_alert.include?(facility.to_s) && feature_toggle_enabled?
        end
      end

      def user_facility_migrating_to_oh?
        return false if @current_user.va_treatment_facility_ids.blank?

        @current_user.va_treatment_facility_ids.any? do |facility|
          facilities_migrating_to_oh.include?(facility.to_s)
        end
      end

      # Returns migration information for facilities the user is associated with.
      # Response includes migration dates, facilities, current phase, and migration status.
      # @return [Array<Hash>] Array of migration info objects, empty array on error or no matches
      def get_oh_migration_info
        build_migration_response
      rescue => e
        Rails.logger.error(
          'OH Migration Info Error: Failed to build migration response',
          {
            error_class: e.class.name,
            error_message: e.message,
            user_uuid: @current_user&.uuid
          }
        )
        []
      end

      private

      def pretransitioned_oh_facilities
        @pretransitioned_oh_facilities ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.pretransitioned_oh_facilities
        )
      end

      def facilities_ready_for_info_alert
        @facilities_ready_for_info_alert ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.facilities_ready_for_info_alert
        )
      end

      def facilities_migrating_to_oh
        @facilities_migrating_to_oh ||= parse_facility_setting(
          Settings.mhv.oh_facility_checks.facilities_migrating_to_oh
        )
      end

      def parse_facility_setting(value)
        return [] unless ActiveModel::Type::Boolean.new.cast(value)

        value.to_s.split(',').map(&:strip).compact_blank
      end

      def feature_toggle_enabled?
        ActiveModel::Type::Boolean.new.cast(
          # Check the main "power switch" toggle
          Flipper.enabled?(:mhv_accelerated_delivery_enabled, @current_user) &&
            # check list of all OH feature toggles
            # if any are enabled, return true
            OH_FEATURE_TOGGLES.any? { |toggle| Flipper.enabled?(toggle, @current_user) }
        )
      rescue
        false
      end

      # Builds the migration response array for user's matching facilities
      def build_migration_response
        return [] if @current_user.va_treatment_facility_ids.blank?

        parsed_migrations = parse_oh_migrations_list
        return [] if parsed_migrations.empty?

        user_migrations = filter_and_merge_user_facilities(parsed_migrations)
        return [] if user_migrations.empty?

        user_migrations.map do |migration|
          migration_date = Date.parse(migration[:migration_date])
          {
            migration_date: format_phase_date(migration_date),
            facilities: migration[:facilities],
            migration_status: determine_migration_status(migration_date),
            phases: build_phases_hash(migration_date)
          }
        end
      end

      # Parses the oh_migrations_list parameter store string into structured data
      # Format: "date1:[id1,name1],[id2,name2];date2:[id3,name3]"
      # @return [Array<Hash>] Array of { migration_date:, facilities: [] }
      def parse_oh_migrations_list
        raw_value = Settings.mhv.oh_facility_checks.oh_migrations_list
        return [] unless ActiveModel::Type::Boolean.new.cast(raw_value)

        raw_value.to_s.split(';').filter_map do |migration_entry|
          migration_entry = migration_entry.strip
          next if migration_entry.blank?

          parse_single_migration_entry(migration_entry)
        end.compact
      end

      # Parses a single migration entry like "2026-05-01:[123,Facility A],[456,Facility B]"
      def parse_single_migration_entry(entry)
        date_part, facilities_part = entry.split(':', 2)
        return nil if date_part.blank? || facilities_part.blank?

        facilities = parse_facilities_from_string(facilities_part)
        return nil if facilities.empty?

        {
          migration_date: date_part.strip,
          facilities:
        }
      end

      # Parses facilities from bracket-delimited string like "[123,Facility A],[456,Facility B]"
      def parse_facilities_from_string(facilities_string)
        facilities_string.scan(/\[([^\]]+)\]/).filter_map do |match|
          parts = match[0].split(',', 2)
          next if parts.length < 2 || parts[0].blank?

          {
            id: parts[0].strip,
            name: parts[1]&.strip || ''
          }
        end
      end

      # Filters migrations to only include user's facilities and merges same-date entries
      def filter_and_merge_user_facilities(migrations)
        user_facility_ids = @current_user.va_treatment_facility_ids.map(&:to_s)

        # Group by migration date and collect matching facilities
        grouped = migrations.each_with_object({}) do |migration, acc|
          matching_facilities = migration[:facilities].select do |facility|
            user_facility_ids.include?(facility[:id].to_s)
          end

          next if matching_facilities.empty?

          date = migration[:migration_date]
          acc[date] ||= { migration_date: date, facilities: [] }
          acc[date][:facilities].concat(matching_facilities)
        end

        grouped.values
      end

      # Builds the phases hash with current phase and formatted dates
      def build_phases_hash(migration_date)
        phase_dates = calculate_phase_dates(migration_date)
        current = determine_current_phase(migration_date)

        { current: }.merge(phase_dates)
      end

      # Calculates absolute dates for each phase based on migration date
      # @return [Hash] Phase keys with formatted date strings
      def calculate_phase_dates(migration_date)
        PHASES.transform_values do |day_offset|
          format_phase_date(migration_date + day_offset)
        end
      end

      # Determines the current phase based on today's date (inclusive boundaries)
      # @return [String, nil] Phase identifier (e.g., "p1") or nil if outside active window
      def determine_current_phase(migration_date)
        today = Time.zone.today
        days_until_migration = (migration_date - today).to_i

        # Find the current phase by checking from latest phase to earliest
        # Phase boundaries are inclusive - if today is day -45, we're in p1
        sorted_phases = PHASES.sort_by { |_, offset| -offset }

        sorted_phases.each do |phase_name, day_offset|
          return phase_name.to_s if days_until_migration <= -day_offset
        end

        # If we haven't returned yet, we're before p0 (NOT_STARTED)
        nil
      end

      # Determines migration status based on today's date relative to migration
      # @return [String] NOT_STARTED, ACTIVE, or COMPLETE
      def determine_migration_status(migration_date)
        today = Time.zone.today
        days_until_migration = (migration_date - today).to_i

        p0_offset = PHASES[:p0] # -60
        p7_offset = PHASES[:p7] # 7

        if days_until_migration > -p0_offset
          MIGRATION_STATUS[:not_started]
        elsif days_until_migration >= -p7_offset
          MIGRATION_STATUS[:active]
        else
          MIGRATION_STATUS[:complete]
        end
      end

      # Formats a date as human-readable string
      # @return [String] Formatted date like "March 3, 2026"
      def format_phase_date(date)
        date.strftime('%B %-d, %Y')
      end
    end
  end
end
