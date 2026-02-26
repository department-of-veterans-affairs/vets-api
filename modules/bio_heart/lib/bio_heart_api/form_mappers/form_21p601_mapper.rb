# frozen_string_literal: true

require 'bio_heart_api/form_mappers/base_mapper'

module BioHeartApi
  module FormMappers
    class Form21p601Mapper < BioHeartApi::FormMappers::BaseMapper
      FORM_TYPE = '21P-601'

      # rubocop:disable Metrics/MethodLength
      def call
        form = @params.to_h.with_indifferent_access

        # Build the IBM payload according to the data dictionary
        payload = {
          # Box 1 - Veteran's Name
          'VETERAN_NAME' => build_full_name(form.dig('veteran', 'full_name')),
          'VETERAN_FIRST_NAME' => form.dig('veteran', 'full_name', 'first'),
          'VETERAN_MIDDLE_INITIAL' => extract_middle_initial(form.dig('veteran', 'full_name')),
          'VETERAN_LAST_NAME' => form.dig('veteran', 'full_name', 'last'),

          # Box 2 - Veteran's Social Security Number
          'VETERAN_SSN' => format_ssn(form.dig('veteran', 'ssn')),

          # Box 3 - VA File Number
          'VA_FILE_NUMBER' => form.dig('veteran', 'va_file_number').presence,

          # Box 4 - Name of Deceased Beneficiary
          'DECEDENT_NAME' => build_full_name(form.dig('beneficiary', 'full_name')),

          # Box 5 - Beneficiary Date of Death
          'DECEASED_DEATH_DATE' => parse_date(form.dig('beneficiary', 'date_of_death')),

          # Box 6 - Claimant Name
          'CLAIMANT_NAME' => build_full_name(form.dig('claimant', 'full_name')),
          'CLAIMANT_FIRST_NAME' => form.dig('claimant', 'full_name', 'first'),
          'CLAIMANT_MIDDLE_INITIAL' => extract_middle_initial(form.dig('claimant', 'full_name')),
          'CLAIMANT_LAST_NAME' => form.dig('claimant', 'full_name', 'last'),

          # Box 7 - Claimant Social Security Number
          'CLAIMANT_SSN' => format_ssn(form.dig('claimant', 'ssn')),

          # Box 8 - Claimant Date of Birth
          'CLAIMANT_DOB' => parse_date(form.dig('claimant', 'date_of_birth')),

          # Box 9 - Claimant Current Mailing Address
          'CLAIMANT_ADDRESS_FULL_BLOCK' => build_full_address(form.dig('claimant', 'address')),
          'CLAIMANT_ADDRESS_LINE1' => form.dig('claimant', 'address', 'street'),
          'CLAIMANT_ADDRESS_LINE2' => form.dig('claimant', 'address', 'street2'),
          'CLAIMANT_ADDRESS_CITY' => form.dig('claimant', 'address', 'city'),
          'CLAIMANT_ADDRESS_STATE' => form.dig('claimant', 'address', 'state'),
          'CLAIMANT_ADDRESS_COUNTRY' => form.dig('claimant', 'address', 'country'),
          'CLAIMANT_ADDRESS_ZIP5' => extract_zip5(form.dig('claimant', 'address', 'zip_code')),

          # Box 10 - Claimant Telephone Number
          'CLAIMANT_PHONE_NUMBER' => format_phone(form.dig('claimant', 'phone')),

          # Box 11 - Preferred E-Mail Address
          'CLAIMANT_EMAIL' => form.dig('claimant', 'email'),

          # Box 12 - Claimant Relationship to Deceased Beneficiary
          'CLAIMANT_RELATIONSHIP' => form.dig('claimant', 'relationship_to_deceased'),

          # Box 13 - Who are the deceased beneficiary's Surviving Relatives?
          'RELATIONSHIP_SURVIVING_SPOUSE' => surviving_relatives_has_type?(form, 'has_spouse'),
          'RELATIONSHIP_CHILD' => surviving_relatives_has_type?(form, 'has_children'),
          'RELATIONSHIP_PARENT' => surviving_relatives_has_type?(form, 'has_parents'),
          'RELATIONSHIP_NONE' => surviving_relatives_has_type?(form, 'has_none'),

          # Box 14E - Would you like to waive substitution?
          'WAIVE_YES' => waive_substitution_yes?(form),
          'WAIVE_NO' => waive_substitution_no?(form),

          # Box 16 - Have you been reimbursed from any source?
          'REIMBURSED_YES' => reimbursed_yes?(form),
          'REIMBURSED_NO' => reimbursed_no?(form),

          # Box 17 - Did the beneficiary leave any other debts?
          'OTHER_DEBTS_YES' => other_debts_exist?(form),
          'OTHER_DEBTS_NO' => other_debts_none?(form),

          # ---
          # These additional keys are not currently provided by the frontend, but
          # must be present in the object sent to MMS. The FE doesn't provide these
          # because they involve 3rd party signatures which is currently not supported.
          'ESTATE_ADMIN_YES' => nil,
          'ESTATE_ADMIN_NO' => nil,
          'OTHER_DEBT_CREDITOR_1' => nil,
          'OTHER_DEBT_CREDITOR_ADDRESS_1' => nil,
          'OTHER_DEBT_CREDITOR_SIGN_1' => nil,
          'OTHER_DEBT_CREDITOR_TITLE_1' => nil,
          'OTHER_DEBT_CREDITOR_DATE_1' => nil,
          'OTHER_DEBT_CREDITOR_2' => nil,
          'OTHER_DEBT_CREDITOR_ADDRESS_2' => nil,
          'OTHER_DEBT_CREDITOR_SIGN_2' => nil,
          'OTHER_DEBT_CREDITOR_TITLE_2' => nil,
          'OTHER_DEBT_CREDITOR_DATE_2' => nil,
          'OTHER_DEBT_CREDITOR_3' => nil,
          'OTHER_DEBT_CREDITOR_ADDRESS_3' => nil,
          'OTHER_DEBT_CREDITOR_SIGN_3' => nil,
          'OTHER_DEBT_CREDITOR_TITLE_3' => nil,
          'OTHER_DEBT_CREDITOR_DATE_3' => nil,
          'WITNESS_1_SIGNATURE' => nil,
          'WITNESS_1_NAME_ADDRESS' => nil,
          'WITNESS_2_SIGNATURE' => nil,
          'WITNESS_2_NAME_ADDRESS' => nil,
          # ---

          # Box 23A - Signature of Claimant
          'CLAIMANT_SIGNATURE' => form.dig('claimant', 'signature'),

          # Box 23B - Today's date
          'DATE_OF_CLAIMANT_SIGNATURE' => parse_date(form.dig('claimant', 'signature_date')),

          # Box 26 - Remarks
          'REMARKS' => form['remarks'],

          # Form Type (must be prefixed with StructuredData: to be ingested)
          'FORM_TYPE' => "StructuredData:#{FORM_TYPE}"
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

      # Build full address string from address hash
      #
      # @param address_hash [Hash, nil] Hash with address components
      # @return [String, nil] Full address or nil
      def build_full_address(address_hash)
        return nil unless address_hash

        parts = [
          address_hash['street'],
          address_hash['street2'],
          address_hash['city'],
          address_hash['state'],
          address_hash['country'],
          format_zip_full(address_hash['zip_code'])
        ].compact.compact_blank

        parts.any? ? parts.join(', ') : nil
      end

      # Extract 5-digit ZIP code from zip_code hash
      #
      # @param zip_hash [Hash, nil] Hash with 'first5' and 'last4' keys
      # @return [String, nil] 5-digit ZIP or nil
      def extract_zip5(zip_hash)
        return nil unless zip_hash

        zip_hash['first5']
      end

      # Format full ZIP code from zip_code hash
      #
      # @param zip_hash [Hash, nil] Hash with 'first5' and 'last4' keys
      # @return [String, nil] Formatted ZIP or nil
      def format_zip_full(zip_hash)
        return nil unless zip_hash && zip_hash['first5'].present?

        if zip_hash['last4'].present?
          "#{zip_hash['first5']}-#{zip_hash['last4']}"
        else
          zip_hash['first5']
        end
      end

      # Format phone number from phone hash
      #
      # @param phone_hash [Hash, nil] Hash with 'area_code', 'prefix', 'line_number' keys
      # @return [String, nil] Formatted phone number or nil
      def format_phone(phone_hash)
        return nil unless phone_hash && [phone_hash['area_code'], phone_hash['prefix'],
                                         phone_hash['line_number']].none?(&:blank?)

        "#{phone_hash['area_code']}#{phone_hash['prefix']}#{phone_hash['line_number']}"
      end

      # Check if surviving relatives has a specific type
      #
      # @param form [Hash] The form data
      # @param type [String] The type to check (e.g., 'has_spouse')
      # @return [Int] 1 if type exists, 0 otherwise
      def surviving_relatives_has_type?(form, type)
        form.dig('surviving_relatives', type) == true ? 1 : 0
      end

      # Determine if waive substitution YES checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [Int] 1 if wants to waive, 0 otherwise
      def waive_substitution_yes?(form)
        form.dig('surviving_relatives', 'wants_to_waive_substitution') == true ? 1 : 0
      end

      # Determine if waive substitution NO checkbox should be checked
      #
      # @param form [Hash] The form data
      # @return [Int] 1 if does not want to waive, 0 otherwise
      def waive_substitution_no?(form)
        form.dig('surviving_relatives', 'wants_to_waive_substitution') == false ? 1 : 0
      end

      # Check if there are other debts
      #
      # @param form [Hash] The form data
      # @return [Int] 1 if other debts exist, 0 otherwise
      def other_debts_exist?(form)
        other_debts = form.dig('expenses', 'other_debts')
        other_debts.is_a?(Array) && other_debts.any? ? 1 : 0
      end

      # Check if there are no other debts
      #
      # @param form [Hash] The form data
      # @return [Int] 1 if no other debts, 0 otherwise
      def other_debts_none?(form)
        other_debts = form.dig('expenses', 'other_debts')
        !other_debts.is_a?(Array) || other_debts.empty? ? 1 : 0
      end

      # Determine if reimbursed YES checkbox should be checked
      # Note: This field is not in the frontend payload, so always returns false
      #
      # @param form [Hash] The form data
      # @return [Int] 0
      def reimbursed_yes?(_form)
        0
      end

      # Determine if reimbursed NO checkbox should be checked
      # Note: This field is not in the frontend payload, so always returns false
      #
      # @param form [Hash] The form data
      # @return [Int] 0
      def reimbursed_no?(_form)
        0
      end

      # Add surviving relatives data (Box 14A-D, up to 4)
      #
      # @param payload [Hash] The payload to add data to
      # @param form [Hash] The form data
      def add_surviving_relatives(payload, form)
        relatives = form.dig('surviving_relatives', 'relatives') || []

        relatives.take(4).each_with_index do |relative, index|
          num = index + 1
          payload["NAME_OF_RELATIVE_#{num}"] = build_full_name(relative['full_name'])
          payload["RELATION_RELATIVE_#{num}"] = relative['relationship']
          payload["DOB_RELATIVE_#{num}"] = parse_date(relative['date_of_birth'])
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

      # Add expenses data (Box 15A-E, up to 4)
      #
      # @param payload [Hash] The payload to add data to
      # @param form [Hash] The form data
      def add_expenses(payload, form)
        expenses = form.dig('expenses', 'expenses_list') || []

        expenses.take(4).each_with_index do |expense, index|
          num = index + 1
          payload["EXPENSE_PAID_TO_#{num}"] = expense['provider']
          payload["EXPENSE_PAID_FOR_#{num}"] = expense['expense_type']
          payload["EXPENSE_AMT_#{num}"] = format_currency(expense['amount'])
          payload["PAID_#{num}"] = expense['is_paid'] == true ? 1 : 0
          payload["UNPAID_#{num}"] = expense['is_paid'] == false ? 1 : 0
          payload["EXPENSE_PAID_BY_#{num}"] = expense['paid_by']
        end

        # Fill remaining slots with nil/false
        ((expenses.length + 1)..4).each do |num|
          payload["EXPENSE_PAID_TO_#{num}"] = nil
          payload["EXPENSE_PAID_FOR_#{num}"] = nil
          payload["EXPENSE_AMT_#{num}"] = nil
          payload["PAID_#{num}"] = 0
          payload["UNPAID_#{num}"] = 0
          payload["EXPENSE_PAID_BY_#{num}"] = nil
        end
      end

      # Add other debts data (Box 18A-B, up to 4)
      #
      # @param payload [Hash] The payload to add data to
      # @param form [Hash] The form data
      def add_other_debts(payload, form)
        other_debts = form.dig('expenses', 'other_debts') || []

        other_debts.take(4).each_with_index do |debt, index|
          num = index + 1
          payload["OTHER_DEBT_#{num}"] = debt['debt_type']
          payload["OTHER_DEBT_AMOUNT_#{num}"] = format_currency(debt['debt_amount'])
        end

        # Fill remaining slots with nil
        ((other_debts.length + 1)..4).each do |num|
          payload["OTHER_DEBT_#{num}"] = nil
          payload["OTHER_DEBT_AMOUNT_#{num}"] = nil
        end
      end

      # Format currency value
      #
      # @param amount [Numeric, String, nil] The amount to format
      # @return [String, nil] Formatted currency or nil
      def format_currency(amount)
        return nil if amount.nil?

        ActiveSupport::NumberHelper.number_to_currency(amount)
      end
    end
  end
end
