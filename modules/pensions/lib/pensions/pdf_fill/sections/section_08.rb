# frozen_string_literal: true

require_relative '../section'

# rubocop:disable Metrics/MethodLength

module Pensions
  module PdfFill
    # Section VIII: Dependent Children
    class Section8 < Section
      # Section configuration hash
      KEY = {
        # 8a
        'dependentChildrenInHousehold' => {
          limit: 2,
          key: 'form1[0].#subform[50].Number_Of_Dependent_Children_Who_Live_With_You[0]'
        },
        # 8b-p Dependent Children
        'dependents' => {
          limit: 3,
          first_key: 'childPlaceOfBirth',
          item_label: 'Child',
          'fullName' => {
            'first' => {
              limit: 12,
              question_num: 8,
              question_label: "Child's First Name",
              question_text: 'CHILD\'S FIRST NAME',
              key: "Dependent_Children.Childs_FirstName[#{ITERATOR}]"
            },
            'middle' => {
              question_num: 8,
              question_label: "Child's Middle Name",
              question_text: 'CHILD\'S MIDDLE NAME',
              key: "Dependent_Children.Childs_MiddleInitial1[#{ITERATOR}]"
            },
            'last' => {
              limit: 18,
              question_num: 8,
              question_label: "Child's Last Name",
              question_text: 'CHILD\'S LAST NAME',
              key: "Dependent_Children.Childs_LastName[#{ITERATOR}]"
            }
          },
          'fullNameOverflow' => {
            question_num: 8,
            question_label: "Child's Name",
            question_text: '(1) CHILD\'S NAME'
          },
          'childDateOfBirth' => {
            'month' => {
              key: "Dependent_Children.Childs_DOB_Month[#{ITERATOR}]"
            },
            'day' => {
              key: "Dependent_Children.Childs_DOB_Day[#{ITERATOR}]"
            },
            'year' => {
              key: "Dependent_Children.Childs_DOB_Year[#{ITERATOR}]"
            }
          },
          'childDateOfBirthOverflow' => {
            question_num: 8,
            question_label: "Child's Date Of Birth",
            question_text: '(2) CHILD\'S DATE OF BIRTH'
          },
          'childSocialSecurityNumber' => {
            'first' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_FirstThreeNumbers[#{ITERATOR}]"
            },
            'second' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_SecondTwoNumbers[#{ITERATOR}]"
            },
            'third' => {
              key: "Dependent_Children.Childs_SocialSecurityNumber_LastFourNumbers[#{ITERATOR}]"
            }
          },
          'childSocialSecurityNumberOverflow' => {
            question_num: 8,
            question_label: "Child's Social Security Number",
            question_text: '(4) CHILD\'S SOCIAL SECURITY NUMBER'
          },
          'childPlaceOfBirth' => {
            limit: 60,
            question_num: 8,
            question_label: "Child's Place Of Birth",
            question_text: '(3) CHILD\'S PLACE OF BIRTH',
            key: "Dependent_Children.Place_Of_Birth_City_And_State_Or_Country[#{ITERATOR}]"
          },
          'childRelationship' => {
            'biological' => {
              key: "Dependent_Children.Biological[#{ITERATOR}]"
            },
            'adopted' => {
              key: "Dependent_Children.Adopted[#{ITERATOR}]"
            },
            'stepchild' => {
              key: "Dependent_Children.Stepchild[#{ITERATOR}]"
            }
          },
          'disabled' => {
            key: "Dependent_Children.Seriously_Disabled[#{ITERATOR}]"
          },
          'attendingCollege' => {
            key: "Dependent_Children.Eighteen_To_Twenty_Three_Years_Old_In_School[#{ITERATOR}]"
          },
          'previouslyMarried' => {
            key: "Dependent_Children.Previously_Married[#{ITERATOR}]"
          },
          'childNotInHousehold' => {
            key: "Dependent_Children.Does_Not_Live_With_You_But_Contributes[#{ITERATOR}]"
          },
          'childStatusOverflow' => {
            question_num: 8,
            question_label: "Child's Status",
            question_text: '(5) CHILD\'S STATUS'
          },
          'monthlyPayment' => {
            'part_two' => {
              key: "Dependent_Children.Amount_Of_Contribution_First_Two[#{ITERATOR}]"
            },
            'part_one' => {
              key: "Dependent_Children.Amount_Of_Contribution_Last_Three[#{ITERATOR}]"
            },
            'part_cents' => {
              key: "Dependent_Children.Amount_Of_Contribution_Cents[#{ITERATOR}]"
            }
          },
          'monthlyPaymentOverflow' => {
            question_num: 8,
            question_label: 'Annual Contribution To Child',
            question_text: '(6) Annual Contribution To Child'
          }
        },
        # 8q
        'dependentsNotWithYouAtSameAddress' => {
          key: 'form1[0].#subform[51].RadioButtonList[20]'
        },
        # 8r
        'custodians' => {
          limit: 1,
          first_key: 'first',
          'first' => {
            limit: 12,
            key: 'form1[0].#subform[51].Custodians_FirstName[0]',
            question_num: 8,
            question_suffix: 'R',
            question_label: "Custodian's First Name",
            question_text: 'CUSTODIAN\'S FIRST NAME'
          },
          'middle' => {
            key: 'form1[0].#subform[51].Custodians_MiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            key: 'form1[0].#subform[51].Custodians_LastName[0]',
            question_num: 8,
            question_suffix: 'R',
            question_label: "Custodian's Last Name",
            question_text: 'CUSTODIAN\'S LAST NAME'
          },
          'custodianAddress' => {
            'street' => {
              limit: 30,
              key: 'form1[0].#subform[51].NumberStreet[3]'
            },
            'street2' => {
              limit: 5,
              key: 'form1[0].#subform[51].Apt_Or_Unit_Number[2]'
            },
            'city' => {
              limit: 18,
              key: 'form1[0].#subform[51].City[2]'
            },
            'state' => {
              key: 'form1[0].#subform[51].State_Or_Province[1]'
            },
            'country' => {
              key: 'form1[0].#subform[51].Country[2]'
            },
            'postalCode' => {
              'firstFive' => {
                key: 'form1[0].#subform[51].Zip_Postal_Code[4]'
              },
              'lastFour' => {
                key: 'form1[0].#subform[51].Zip_Postal_Code[5]'
              }
            }
          },
          'custodianAddressOverflow' => {
            question_num: 8,
            question_suffix: 'R',
            question_label: "Custodian's Address",
            question_text: 'CUSTODIAN\'S ADDRESS'
          },
          'dependentsWithCustodianOverflow' => {
            question_num: 8,
            question_suffix: 'R',
            question_label: 'Dependents Living With This Custodian',
            question_text: 'DEPENDENTS LIVING WITH THIS CUSTODIAN'
          }
        }
      }.freeze

      ##
      # Expands dependent children section
      #
      # @param form_data [Hash]
      #
      # @return [void]
      #
      # @note Modifies `form_data`
      #
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

      ##
      # Create an address string from an address hash
      #
      # @param address [Hash]
      #
      # @return [String]
      #
      # @note Returns empty string if address is blank
      #
      def build_address_string(address)
        return '' if address.blank?

        country = address['country'].present? ? "#{address['country']}, " : ''
        address_arr = [
          address['street'].to_s, address['street2'].presence,
          "#{address['city']}, #{address['state']}, #{country}#{address['postalCode']}"
        ].compact

        address_arr.join("\n")
      end

      ##
      # Select the children in a household of the dependents
      #
      # @param dependents [Array<Hash>]
      #
      # @return [String] Number of children in household as string
      #
      def select_children_in_household(dependents)
        return unless dependents&.any?

        dependents.select do |dependent|
          dependent['childInHousehold']
        end.length.to_s
      end

      ##
      # Build a string to represent the dependents status.
      #
      # @param dependent [Hash]
      #
      # @return [Array<String>] Array of status strings
      #
      def child_status_overflow(dependent)
        child_status_overflow = [dependent['childRelationship']&.humanize]
        child_status_overflow << 'seriously disabled' if dependent['disabled']
        child_status_overflow << '18-23 years old (in school)' if dependent['attendingCollege']
        child_status_overflow << 'previously married' if dependent['previouslyMarried']
        child_status_overflow << 'does not live with you but contributes' unless dependent['childInHousehold']
        child_status_overflow
      end

      ##
      # Create a hash table from a dependent that outlines all the data joined and formatted together
      #
      # @param dependent [Hash]
      #
      # @return [Hash] The formatted dependent hash
      #
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
