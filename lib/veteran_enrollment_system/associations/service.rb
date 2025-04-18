# frozen_string_literal: true

require 'veteran_enrollment_system/associations/configuration'

module VeteranEnrollmentSystem
  module Associations
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring
      include HCA::EnrollmentSystem

      configuration VeteranEnrollmentSystem::Associations::Configuration

      STATSD_KEY_PREFIX = 'api.veteran_enrollment_system.associations'

      # Maps Associations API field names to 10-10EZR schema field names
      ASSOCIATION_MAPPINGS = {
        'role' => 'contactType',
        'relationType' => 'relationship'
      }.freeze

      def initialize(current_user, parsed_form)
        super()
        @current_user = current_user
        @parsed_form = parsed_form
      end

      def update_associations(form_id)
        with_monitoring do
          transformed_associations = transform_associations(@parsed_form['veteranContacts'])

          perform(
            :put,
            "#{config.base_path}/#{@current_user.icn}",
            transformed_associations,
            headers: config.base_request_headers
          )
        end
      rescue => e
        StatsD.increment("#{STATSD_KEY_PREFIX}.update_associations.failed")
        Rails.logger.info("#{form_id} update associations failed: #{e.message}")

        raise e
      end

      private

      def transform_associations(associations)
        associations.map do |association|
          transformed_association = {}
          # Format the address to match the Associations schema
          transformed_association['address'] = format_address(association['address']).compact_blank
          # Format the name to match the Associations schema
          transformed_association['name'] = convert_full_name_alt(association['fullName']).compact_blank
          transform_top_level_fields(
            association,
            transformed_association
          )
          # This is a required field in the Associations API for insert/update
          transformed_association['lastUpdateDate'] = Time.current.iso8601

          transformed_association
        end
      end

      # Transform top-level fields to match the API schema
      def transform_top_level_fields(association, transformed_association)
        ASSOCIATION_MAPPINGS.each do |api_key, schema_key|
          # 'contactType' needs to be converted to the following format: 'PRIMARY_NEXT_OF_KIN'
          if schema_key == 'contactType'
            transformed_association[api_key] = association[schema_key].to_s.upcase.gsub(/\s+/, '_')
          elsif association[schema_key].present?
            transformed_association[api_key] = association[schema_key]
          end
        end
      end
    end
  end
end
