# frozen_string_literal: true

module VAOS
  module OhMigrationsHelper
    def self.get_migrations
      migrations = {}

      raw_value = Settings.mhv.oh_facility_checks.oh_migrations_list

      return migrations if raw_value.to_s.strip.blank?

      today = Time.use_zone('Eastern Time (US & Canada)') { Date.current }

      raw_value.to_s.split(';').filter_map do |migration_entry_string|
        migration_entry_string = migration_entry_string.strip
        next if migration_entry_string.blank?

        migration_entry = parse_single_migration_entry(migration_entry_string)

        migration_entry[:facilities].each do |facility|
          migration_days = (today - migration_entry[:migration_date]).to_i

          is_minus30 = migration_days >= -30
          is_plus7 = migration_days >= 7

          migrations[facility[:facility_id]] = {
            migration_days:,
            migration_date: migration_entry[:migration_date],

            # eligibility is disabled from 30 days before to 7 days after the migration date
            disable_eligibility: is_minus30 && !is_plus7
          }
        end
      end.compact

      migrations
    end

    def self.parse_single_migration_entry(entry)
      date_part, facilities_part = entry.split(':', 2)
      return nil if date_part.blank? || facilities_part.blank?

      facilities = parse_facilities_from_string(facilities_part)
      return nil if facilities.empty?

      {
        migration_date: Date.parse(date_part.strip),
        facilities:
      }
    end

    # Parses facilities from bracket-delimited string like "[123,Facility A],[456,Facility B]"
    def self.parse_facilities_from_string(facilities_string)
      facilities_string.scan(/\[([^\]]+)\]/).filter_map do |match|
        parts = match[0].split(',', 2)
        next if parts.length < 2 || parts[0].blank?

        {
          facility_id: parts[0].strip,
          facility_name: parts[1]&.strip || ''
        }
      end
    end
  end
end
