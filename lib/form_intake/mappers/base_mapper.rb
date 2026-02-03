# frozen_string_literal: true

module FormIntake
  module Mappers
    # Base class for form-specific GCIO mappers
    # Provides common helpers and interface definition
    class BaseMapper
      attr_reader :form_submission, :benefits_intake_uuid

      def initialize(form_submission, benefits_intake_uuid)
        @form_submission = form_submission
        @benefits_intake_uuid = benefits_intake_uuid
      end

      # Subclasses MUST implement this method
      # @return [Hash] GCIO API payload
      def to_gcio_payload
        raise NotImplementedError, "#{self.class} must implement #to_gcio_payload"
      end

      protected

      # Parsed form data as hash
      def form_data
        @form_data ||= JSON.parse(@form_submission.form_data)
      end

      # Form type string (e.g., '21P-601')
      def form_type
        @form_submission.form_type
      end

      # User account who submitted
      def user_account
        @form_submission.user_account
      end

      # Form submission ID
      def form_submission_id
        @form_submission.id
      end

      # Common field mapping helpers

      def map_ssn(ssn_parts)
        return nil unless ssn_parts
        return nil if ssn_parts['first3'].blank? || ssn_parts['middle2'].blank? || ssn_parts['last4'].blank?

        "#{ssn_parts['first3']}#{ssn_parts['middle2']}#{ssn_parts['last4']}"
      end

      def map_phone(phone_parts)
        return nil unless phone_parts
        if phone_parts['area_code'].blank? || phone_parts['prefix'].blank? || phone_parts['line_number'].blank?
          return nil
        end

        "#{phone_parts['area_code']}#{phone_parts['prefix']}#{phone_parts['line_number']}"
      end

      def map_address(address)
        return nil unless address

        {
          street: address['street'],
          street2: address['street2'],
          city: address['city'],
          state: address['state'],
          country: address['country'],
          postal_code: address.dig('zip_code', 'first5') || address['postal_code']
        }.compact
      end

      def map_date(date_parts)
        return nil unless date_parts
        return nil unless date_parts['year'] && date_parts['month'] && date_parts['day']

        "#{date_parts['year']}-#{format('%02d', date_parts['month'].to_i)}-#{format('%02d', date_parts['day'].to_i)}"
      end

      def map_full_name(name_parts)
        return nil unless name_parts

        {
          first: name_parts['first'],
          middle: name_parts['middle'],
          last: name_parts['last'],
          suffix: name_parts['suffix']
        }.compact
      end
    end
  end
end
