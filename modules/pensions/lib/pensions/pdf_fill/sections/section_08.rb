# frozen_string_literal: true

require_relative '../section'

# rubocop:disable Metrics/MethodLength

module Pensions
  module PdfFill
    # Section VIII: Dependent Children
    class Section8 < Section
      # Section configuration hash
      KEY = {}.freeze

      def expand(form_data)
        form_data['dependentChildrenInHousehold'] = select_children_in_household(form_data['dependents'])
        form_data['dependents'] = form_data['dependents']&.map { |dependent| dependent_to_hash(dependent) }
        # 8Q Do all children not living with you reside at the same address?
        custodian_addresses = {}
        dependents_not_in_household = form_data['dependents']&.reject { |dep| dep['childInHousehold'] } || []
        dependents_not_in_household.each do |dependent|
          custodian_key = dependent['personWhoLivesWithChild'].values.join('_')
          if custodian_addresses[custodian_key].nil?
            custodian_addresses[custodian_key] = build_custodian_hash_from_dependent(dependent)
          else
            custodian_addresses[custodian_key]['dependentsWithCustodianOverflow'] +=
              ", #{dependent['fullName']&.values&.join(' ')}"
          end
        end
        if custodian_addresses.any?
          form_data['dependentsNotWithYouAtSameAddress'] = to_radio_yes_no(custodian_addresses.length == 1)
        end
        form_data['custodians'] = custodian_addresses.values
      end

      # Build the custodian data from dependents
      def build_custodian_hash_from_dependent(dependent)
        dependent = dependent['personWhoLivesWithChild']
                    .merge({
                             'custodianAddress' => dependent['childAddress'].merge(
                               'postalCode' => split_postal_code(dependent['childAddress'])
                             )
                           })
                    .merge({
                             'custodianAddressOverflow' => build_address_string(dependent['childAddress']),
                             'dependentsWithCustodianOverflow' => dependent['fullName']&.values&.join(' ')
                           })
        dependent['custodianAddress']['country'] =
          dependent.dig('custodianAddress', 'country')&.slice(0, 2)
        dependent
      end

      # Create an address string from an address hash
      def build_address_string(address)
        return '' if address.blank?

        country = address['country'].present? ? "#{address['country']}, " : ''
        address_arr = [
          address['street'].to_s, address['street2'].presence,
          "#{address['city']}, #{address['state']}, #{country}#{address['postalCode']}"
        ].compact

        address_arr.join("\n")
      end

      # Select the children in a household of the dependents.
      def select_children_in_household(dependents)
        return unless dependents&.any?

        dependents.select do |dependent|
          dependent['childInHousehold']
        end.length.to_s
      end

      # Build a string to represent the dependents status.
      def child_status_overflow(dependent)
        child_status_overflow = [dependent['childRelationship']&.humanize]
        child_status_overflow << 'seriously disabled' if dependent['disabled']
        child_status_overflow << '18-23 years old (in school)' if dependent['attendingCollege']
        child_status_overflow << 'previously married' if dependent['previouslyMarried']
        child_status_overflow << 'does not live with you but contributes' unless dependent['childInHousehold']
        child_status_overflow
      end

      # Create a hash table from a dependent that outlines all the data joined and formatted together.
      def dependent_to_hash(dependent)
        dependent
          .merge!({
                    'fullNameOverflow' => dependent['fullName']&.values&.join(' '),
                    'childDateOfBirth' => split_date(dependent['childDateOfBirth']),
                    'childDateOfBirthOverflow' => to_date_string(dependent['childDateOfBirth']),
                    'childSocialSecurityNumber' => split_ssn(dependent['childSocialSecurityNumber']),
                    'childSocialSecurityNumberOverflow' => dependent['childSocialSecurityNumber'],
                    'childRelationship' => {
                      'biological' => to_checkbox_on_off(dependent['childRelationship'] == 'BIOLOGICAL'),
                      'adopted' => to_checkbox_on_off(dependent['childRelationship'] == 'ADOPTED'),
                      'stepchild' => to_checkbox_on_off(dependent['childRelationship'] == 'STEP_CHILD')
                    },
                    'disabled' => to_checkbox_on_off(dependent['disabled']),
                    'attendingCollege' => to_checkbox_on_off(dependent['attendingCollege']),
                    'previouslyMarried' => to_checkbox_on_off(dependent['previouslyMarried']),
                    'childNotInHousehold' => to_checkbox_on_off(!dependent['childInHousehold']),
                    'childStatusOverflow' => child_status_overflow(dependent).join(', '),
                    'monthlyPayment' => split_currency_amount(dependent['monthlyPayment']),
                    'monthlyPaymentOverflow' => number_to_currency(dependent['monthlyPayment'])
                  })
        dependent.fetch('fullName', {})['middle'] = dependent.dig('fullName', 'middle')&.first
        if dependent['personWhoLivesWithChild'].present?
          dependent['personWhoLivesWithChild']['middle'] = dependent.dig('personWhoLivesWithChild', 'middle')&.first
        end
        dependent
      end
    end
  end
end

# rubocop:enable Metrics/MethodLength
