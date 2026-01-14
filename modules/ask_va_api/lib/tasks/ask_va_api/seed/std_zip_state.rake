# frozen_string_literal: true

namespace :ask_va_api do
  namespace :seed do
    desc <<~DESC
      Seed minimal state and zip data for AskVA zip/state validation in development only

      Usage:
        bundle exec rails ask_va_api:seed:std_zip_state
        RESET=true bundle exec rails ask_va_api:seed:std_zip_state
    DESC
    task std_zip_state: :environment do
      abort 'This task can only be run in development environment. Task aborted!' unless Rails.env.development?

      require_relative '../../../ask_va_api/seed/std_zip_state_records'
      data = AskVAApi::Seed::StdZipStateRecords

      if ActiveModel::Type::Boolean.new.cast(ENV.fetch('RESET', nil))
        StdZipcode.where(zip_code: data::ZIPCODES.map { |z| z[:zip_code] }).delete_all
        StdState.where(postal_name: data::STATES.map { |s| s[:postal_name] }).delete_all
      end

      data::STATES.each do |attrs|
        state = StdState.find_or_initialize_by(postal_name: attrs[:postal_name])
        state.id ||= attrs[:id]
        state.assign_attributes(
          name: attrs[:name],
          fips_code: attrs[:fips_code],
          country_id: attrs[:country_id],
          version: attrs[:version],
          created: attrs[:created]
        )
        state.save!
      end

      state_ids = StdState.where(postal_name: data::STATE_CODES).pluck(:postal_name, :id).to_h

      data::ZIPCODES.each do |attrs|
        zip = StdZipcode.find_or_initialize_by(zip_code: attrs[:zip_code])
        zip.id ||= attrs[:id]
        zip.assign_attributes(
          state_id: state_ids[attrs[:state_code]],
          county_number: attrs[:county_number],
          version: attrs[:version],
          created: attrs[:created]
        )
        zip.save!
      end

      Rails.logger.info("Seeded states=#{data::STATES.size}, zipcodes=#{data::ZIPCODES.size}")
    end
  end
end
