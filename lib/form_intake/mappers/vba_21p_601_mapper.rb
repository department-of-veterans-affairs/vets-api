# frozen_string_literal: true

module FormIntake
  module Mappers
    # Mapper for form 21P-601 (Application for Accrued Amounts Due a Deceased Beneficiary)
    # Follows IBM Data Dictionary format (matches BioHeart implementation)
    class VBA21p601Mapper < BaseMapper
      # rubocop:disable Metrics/MethodLength
      def to_gcio_payload
        form = form_data.with_indifferent_access

        payload = {
          # Box 1 - Veteran's Name
          'VETERAN_NAME' => build_full_name(form.dig('veteran', 'fullName')),
          'VETERAN_FIRST_NAME' => form.dig('veteran', 'fullName', 'first'),
          'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(form.dig('veteran', 'fullName')),
          'VETERAN_LAST_NAME' => form.dig('veteran', 'fullName', 'last'),

          # Box 2 - Veteran's Social Security Number
          'VETERAN_SSN' => map_ssn(form.dig('veteran', 'ssn')),

          # Box 3 - VA File Number
          'VA_FILE_NUMBER' => form.dig('veteran', 'vaFileNumber').presence,

          # Box 4 - Name of Deceased Beneficiary
          'DECEDENT_NAME' => build_full_name(form.dig('beneficiary', 'fullName')),

          # Box 5 - Beneficiary Date of Death
          'DECEASED_DEATH_DATE' => map_date(form.dig('beneficiary', 'dateOfDeath')),

          # Box 6 - Claimant Name
          'CLAIMANT_NAME' => build_full_name(form.dig('claimant', 'fullName')),
          'CLAIMANT_FIRST_NAME' => form.dig('claimant', 'fullName', 'first'),
          'CLAIMANT_MIDDLE_INITIAL' => extract_middle_initial(form.dig('claimant', 'fullName')),
          'CLAIMANT_LAST_NAME' => form.dig('claimant', 'fullName', 'last'),

          # Box 7 - Claimant Social Security Number
          'CLAIMANT_SSN' => map_ssn(form.dig('claimant', 'ssn')),

          # Box 8 - Claimant Date of Birth
          'CLAIMANT_DOB' => map_date(form.dig('claimant', 'dateOfBirth')),

          # Box 9 - Claimant Current Mailing Address
          'CLAIMANT_ADDRESS_FULL_BLOCK' => build_full_address(form.dig('claimant', 'address')),
          'CLAIMANT_ADDRESS_LINE1' => form.dig('claimant', 'address', 'street'),
          'CLAIMANT_ADDRESS_LINE2' => form.dig('claimant', 'address', 'street2'),
          'CLAIMANT_ADDRESS_CITY' => form.dig('claimant', 'address', 'city'),
          'CLAIMANT_ADDRESS_STATE' => form.dig('claimant', 'address', 'state'),
          'CLAIMANT_ADDRESS_COUNTRY' => form.dig('claimant', 'address', 'country'),
          'CLAIMANT_ADDRESS_ZIP5' => extract_zip5(form.dig('claimant', 'address', 'zipCode')),

          # Box 10 - Claimant Telephone Number
          'CLAIMANT_PHONE_NUMBER' => map_phone_camel_case(form.dig('claimant', 'phone')),

          # Box 11 - Preferred E-Mail Address
          'CLAIMANT_EMAIL' => form.dig('claimant', 'email'),

          # Box 12 - Claimant Relationship to Deceased Beneficiary
          'CLAIMANT_RELATIONSHIP' => form.dig('claimant', 'relationshipToDeceased'),

          # Box 13 - Who are the deceased beneficiary's Surviving Relatives?
          'RELATIONSHIP_SURVIVING_SPOUSE' => surviving_relatives_has_type?(form, 'hasSpouse'),
          'RELATIONSHIP_CHILD' => surviving_relatives_has_type?(form, 'hasChildren'),
          'RELATIONSHIP_PARENT' => surviving_relatives_has_type?(form, 'hasParents'),
          'RELATIONSHIP_NONE' => surviving_relatives_has_type?(form, 'hasNone'),

          # Box 14E - Would you like to waive substitution?
          'WAIVE_YES' => waive_substitution_yes?(form),
          'WAIVE_NO' => waive_substitution_no?(form),

          # Box 16 - Have you been reimbursed from any source?
          'REIMBURSED_YES' => false,
          'REIMBURSED_NO' => false,

          # Box 17 - Did the beneficiary leave any other debts?
          'OTHER_DEBTS_YES' => other_debts_exist?(form),
          'OTHER_DEBTS_NO' => other_debts_none?(form),

          # Box 23A - Signature of Claimant
          'CLAIMANT_SIGNATURE' => form.dig('claimant', 'signature'),

          # Box 23B - Today's date
          'DATE_OF_CLAIMANT_SIGNATURE' => map_date(form.dig('claimant', 'signatureDate')),

          # Box 26 - Remarks
          'REMARKS' => form['remarks'],

          # Form Type (must be prefixed with StructuredData: to be ingested)
          'FORM_TYPE' => 'StructuredData:21P-601'
        }

        # Add Box 14A-D - Surviving Relatives (up to 4)
        add_surviving_relatives(payload, form)

        # Add Box 15A-E - Expenses (up to 4)
        add_expenses(payload, form)

        # Add Box 18A-B - Other Debts (up to 4)
        add_other_debts(payload, form)

        payload
      end
      # rubocop:enable Metrics/MethodLength

      private

      def build_full_name(name_hash)
        return nil unless name_hash

        parts = [
          name_hash['first'],
          name_hash['middle'],
          name_hash['last']
        ].compact.compact_blank

        parts.any? ? parts.join(' ') : nil
      end

      def extract_middle_initial(name_hash)
        return nil unless name_hash && name_hash['middle'].present?

        name_hash['middle'][0]
      end

      def build_full_address(address_hash)
        return nil unless address_hash

        parts = [
          address_hash['street'],
          address_hash['street2'],
          address_hash['city'],
          address_hash['state'],
          address_hash['country'],
          format_zip_full(address_hash['zipCode'])
        ].compact.compact_blank

        parts.any? ? parts.join(', ') : nil
      end

      def extract_zip5(zip_hash)
        return nil unless zip_hash

        zip_hash['first5']
      end

      def format_zip_full(zip_hash)
        return nil unless zip_hash && zip_hash['first5'].present?

        if zip_hash['last4'].present?
          "#{zip_hash['first5']}-#{zip_hash['last4']}"
        else
          zip_hash['first5']
        end
      end

      def map_phone_camel_case(phone_hash)
        return nil unless phone_hash && [phone_hash['areaCode'], phone_hash['prefix'],
                                         phone_hash['lineNumber']].none?(&:blank?)

        "#{phone_hash['areaCode']}#{phone_hash['prefix']}#{phone_hash['lineNumber']}"
      end

      def surviving_relatives_has_type?(form, type)
        form.dig('survivingRelatives', type) == true
      end

      def waive_substitution_yes?(form)
        form.dig('survivingRelatives', 'wantsToWaiveSubstitution') == true
      end

      def waive_substitution_no?(form)
        form.dig('survivingRelatives', 'wantsToWaiveSubstitution') == false
      end

      def other_debts_exist?(form)
        other_debts = form.dig('expenses', 'otherDebts')
        other_debts.is_a?(Array) && other_debts.any?
      end

      def other_debts_none?(form)
        other_debts = form.dig('expenses', 'otherDebts')
        !other_debts.is_a?(Array) || other_debts.empty?
      end

      def add_surviving_relatives(payload, form)
        relatives = form.dig('survivingRelatives', 'relatives') || []

        relatives.take(4).each_with_index do |relative, index|
          num = index + 1
          payload["NAME_OF_RELATIVE_#{num}"] = build_full_name(relative['fullName'])
          payload["RELATION_RELATIVE_#{num}"] = relative['relationship']
          payload["DOB_RELATIVE_#{num}"] = map_date(relative['dateOfBirth'])
          # "RELEATIVE" is a typo that exists in the data dictionary provided by MMS.
          payload["ADDRESS_RELEATIVE_#{num}"] = build_full_address(relative['address'])
        end

        # Fill remaining slots with nil
        ((relatives.length + 1)..4).each do |num|
          payload["NAME_OF_RELATIVE_#{num}"] = nil
          payload["RELATION_RELATIVE_#{num}"] = nil
          payload["DOB_RELATIVE_#{num}"] = nil
          payload["ADDRESS_RELEATIVE_#{num}"] = nil
        end
      end

      def add_expenses(payload, form)
        expenses = form.dig('expenses', 'expensesList') || []

        expenses.take(4).each_with_index do |expense, index|
          num = index + 1
          payload["EXPENSE_PAID_TO_#{num}"] = expense['provider']
          payload["EXPENSE_PAID_FOR_#{num}"] = expense['expenseType']
          payload["EXPENSE_AMT_#{num}"] = format_currency(expense['amount'])
          payload["PAID_#{num}"] = expense['isPaid'] == true
          payload["UNPAID_#{num}"] = expense['isPaid'] == false
          payload["EXPENSE_PAID_BY_#{num}"] = expense['paidBy']
        end

        # Fill remaining slots with nil/false
        ((expenses.length + 1)..4).each do |num|
          payload["EXPENSE_PAID_TO_#{num}"] = nil
          payload["EXPENSE_PAID_FOR_#{num}"] = nil
          payload["EXPENSE_AMT_#{num}"] = nil
          payload["PAID_#{num}"] = false
          payload["UNPAID_#{num}"] = false
          payload["EXPENSE_PAID_BY_#{num}"] = nil
        end
      end

      def add_other_debts(payload, form)
        other_debts = form.dig('expenses', 'otherDebts') || []

        other_debts.take(4).each_with_index do |debt, index|
          num = index + 1
          payload["OTHER_DEBT_#{num}"] = debt['debtType']
          payload["OTHER_DEBT_AMOUNT_#{num}"] = format_currency(debt['debtAmount'])
        end

        # Fill remaining slots with nil
        ((other_debts.length + 1)..4).each do |num|
          payload["OTHER_DEBT_#{num}"] = nil
          payload["OTHER_DEBT_AMOUNT_#{num}"] = nil
        end
      end

      def format_currency(amount)
        return nil if amount.nil? || amount.to_s.blank?

        format('%.2f', amount.to_f)
      end
    end
  end
end
