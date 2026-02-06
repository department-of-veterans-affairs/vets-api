# frozen_string_literal: true

require_relative 'base'
require 'va_profile/concerns/defaultable'
require 'va_profile/concerns/expirable'

module VAProfile
  module Models
    class PersonOption < Base
      include VAProfile::Concerns::Defaultable
      include VAProfile::Concerns::Expirable

      attribute :id, Integer
      attribute :item_id, Integer
      attribute :option_id, Integer
      attribute :effective_start_date, Vets::Type::ISO8601Time
      attribute :effective_end_date, Vets::Type::ISO8601Time
      attribute :source_date, Vets::Type::ISO8601Time
      attribute :source_system_user, String
      attribute :originating_source_system, String
      attribute :option_label, String
      attribute :option_type_code, String
      attribute :option_value_string, String

      validates(
        :item_id,
        presence: true,
        numericality: { greater_than: 0 }
      )

      validates(
        :option_id,
        presence: true,
        numericality: { greater_than: 0 }
      )

      # Sets the effective_end_date to current time to explicitly remove the selected option
      def mark_for_deletion
        self.effective_end_date = Time.now.utc.iso8601
        self
      end

      # Transform FROM frontend (item_id + option_ids)
      def self.from_frontend_selection(item_id, option_ids)
        Array(option_ids).map do |option_id|
          new(
            item_id:,
            option_id:
          )
        end
      end

      # Transform TO frontend format (group by item_id)
      def self.to_frontend_format(person_options_array)
        person_options_array.group_by(&:item_id).map do |item_id, options|
          {
            item_id:,
            option_ids: options.map(&:option_id).sort
          }
        end
      end

      # Convert model instance to VA Profile API request format
      def in_json
        {
          itemId: @item_id,
          optionId: @option_id,
          effectiveStartDate: @effective_start_date,
          effectiveEndDate: @effective_end_date,
          sourceDate: @source_date,
          sourceSystemUser: @source_system_user,
          originatingSourceSystem: SOURCE_SYSTEM
        }.compact.to_json
      end

      # Build the API payload with the array of PersonOption instances
      def self.to_api_payload(person_options_array)
        {
          bio: {
            personOptions: person_options_array.map do |option|
              JSON.parse(option.in_json).except('bio').transform_keys { |k| k.to_s.camelize(:lower) }
            end
          }
        }
      end

      # Convert single option from VA Profile API response to model instance
      def self.build_from(body)
        new(
          id: body['person_option_id'],
          item_id: body['item_id'],
          option_id: body['option_id'],
          effective_start_date: body['effective_start_date'],
          effective_end_date: body['effective_end_date'],
          source_date: body['source_date'],
          source_system_user: body['source_system_user'],
          originating_source_system: body['originating_source_system'],
          option_label: body['option_label'],
          option_type_code: body['option_type_code'],
          option_value_string: body['option_value_string']
        )
      end

      # Convert VA Profile API GET response to array of PersonOption instances
      def self.build_from_response(response_body)
        return [] if response_body.blank? || response_body['bios'].blank?

        response_body['bios'].map { |bio| build_from(bio) }
      end
    end
  end
end
