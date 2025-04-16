# frozen_string_literal: true

require 'veteran_enrollment_system/base_service'
require 'veteran_enrollment_system/associations/configuration'

module VeteranEnrollmentSystem
  module Associations
    class Service < Common::Client::Base
      include Common::Client::Concerns::Monitoring

      configuration VeteranEnrollmentSystem::Associations::Configuration

      STATSD_KEY_PREFIX = 'api.veteran_enrollment_system.associations'

      # Maps API field names to schema field names
      ASSOCIATION_MAPPINGS = {
        'role' => 'contactType',
        'relationType' => 'relationship',
        'name' => 'fullName',
        'address' => 'address',
        'primaryPhone' => 'primaryPhone',
        'alternatePhone' => 'alternatePhone',
        'deleteIndicator' => 'deleteIndicator'
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
          transformed_association = ASSOCIATION_MAPPINGS.each_with_object({}) do |(api_key, schema_key), obj|
            obj[schema_key] = association[api_key] if association.key?(api_key)
          end
          # This is a required field in VES for insert/update
          transformed_association['lastUpdateDate'] = Time.current.iso8601

          transformed_association
        end
      end
    end
  end
end
