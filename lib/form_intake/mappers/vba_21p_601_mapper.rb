# frozen_string_literal: true

module FormIntake
  module Mappers
    # Mapper for form 21P-601 (Application for Accrued Amounts Due a Deceased Beneficiary)
    class VBA21p601Mapper < BaseMapper
      def to_gcio_payload
        {
          form_number: '21P-601',
          submission_id: form_submission_id,
          benefits_intake_uuid:,
          submitted_at: @form_submission.created_at.iso8601,
          veteran: map_veteran,
          beneficiary: map_beneficiary,
          claimant: map_claimant,
          surviving_relatives: map_surviving_relatives,
          expenses: map_expenses,
          remarks: form_data['remarks']
        }.compact
      end

      private

      def map_veteran
        veteran_data = form_data['veteran']
        return nil unless veteran_data

        {
          first_name: veteran_data.dig('fullName', 'first'),
          middle_name: veteran_data.dig('fullName', 'middle'),
          last_name: veteran_data.dig('fullName', 'last'),
          ssn: map_ssn(veteran_data['ssn']),
          va_file_number: veteran_data['vaFileNumber']
        }.compact
      end

      def map_beneficiary
        beneficiary_data = form_data['beneficiary']
        return nil unless beneficiary_data

        {
          first_name: beneficiary_data.dig('fullName', 'first'),
          middle_name: beneficiary_data.dig('fullName', 'middle'),
          last_name: beneficiary_data.dig('fullName', 'last'),
          date_of_death: map_date(beneficiary_data['dateOfDeath']),
          is_veteran: beneficiary_data['isVeteran']
        }.compact
      end

      def map_claimant
        claimant_data = form_data['claimant']
        return nil unless claimant_data

        {
          first_name: claimant_data.dig('fullName', 'first'),
          middle_name: claimant_data.dig('fullName', 'middle'),
          last_name: claimant_data.dig('fullName', 'last'),
          ssn: map_ssn(claimant_data['ssn']),
          va_file_number: claimant_data['vaFileNumber'].presence,
          date_of_birth: map_date(claimant_data['dateOfBirth']),
          relationship_to_deceased: claimant_data['relationshipToDeceased'],
          address: map_address_camel_case(claimant_data['address']),
          phone: map_phone_camel_case(claimant_data['phone']),
          email: claimant_data['email'],
          signature: claimant_data['signature'],
          signature_date: map_date(claimant_data['signatureDate'])
        }.compact
      end

      def map_surviving_relatives
        relatives_data = form_data['survivingRelatives']
        return nil unless relatives_data

        result = {
          has_spouse: relatives_data['hasSpouse'],
          has_children: relatives_data['hasChildren'],
          has_parents: relatives_data['hasParents'],
          has_none: relatives_data['hasNone'],
          wants_to_waive_substitution: relatives_data['wantsToWaiveSubstitution']
        }

        if relatives_data['relatives']&.any?
          result[:relatives] = relatives_data['relatives'].map do |relative|
            map_relative(relative)
          end.compact
        end

        result.compact
      end

      def map_relative(relative_data)
        return nil unless relative_data

        {
          first_name: relative_data.dig('fullName', 'first'),
          middle_name: relative_data.dig('fullName', 'middle'),
          last_name: relative_data.dig('fullName', 'last'),
          relationship: relative_data['relationship'],
          date_of_birth: map_date(relative_data['dateOfBirth']),
          address: map_address_camel_case(relative_data['address'])
        }.compact
      end

      def map_expenses
        expenses_data = form_data['expenses']
        return nil unless expenses_data

        result = {}

        if expenses_data['expensesList']&.any?
          result[:expenses_list] = expenses_data['expensesList'].map do |expense|
            map_expense(expense)
          end.compact
        end

        if expenses_data['otherDebts']&.any?
          result[:other_debts] = expenses_data['otherDebts'].map do |debt|
            map_debt(debt)
          end.compact
        end

        result.compact.presence
      end

      def map_expense(expense_data)
        return nil unless expense_data

        {
          provider: expense_data['provider'],
          expense_type: expense_data['expenseType'],
          amount: expense_data['amount'],
          is_paid: expense_data['isPaid'],
          paid_by: expense_data['paidBy'].presence
        }.compact
      end

      def map_debt(debt_data)
        return nil unless debt_data

        {
          debt_type: debt_data['debtType'],
          debt_amount: debt_data['debtAmount']
        }.compact
      end

      # Map phone with camelCase keys (specific to 21P-601 format)
      def map_phone_camel_case(phone_parts)
        return nil unless phone_parts

        area_code = phone_parts['areaCode']
        prefix = phone_parts['prefix']
        line_number = phone_parts['lineNumber']

        return nil if area_code.blank? || prefix.blank? || line_number.blank?

        "#{area_code}#{prefix}#{line_number}"
      end

      # Map address with camelCase keys (specific to 21P-601 format)
      def map_address_camel_case(address)
        return nil unless address

        # Flatten address to single string (matches IBM format)
        street_line = [address['street'], address['street2']].compact.join(' ').strip
        postal_code = address.dig('zipCode', 'first5') || address['postal_code']
        city_line = [address['city'], address['state'], postal_code].compact.join(' ').strip
        lines = [street_line, city_line, address['country']].compact.reject(&:empty?)
        lines.join(' ').presence
      end
    end
  end
end

