module PdfFill
  module Forms
    # TODO bring back workflow require statements
    class VA21P530 < FormBase
      ITERATOR = PdfFill::HashConverter::ITERATOR

      PLACE_OF_DEATH_KEY = {
        'vaMedicalCenter' => 'VA MEDICAL CENTER',
        'stateVeteransHome' => 'STATE VETERANS HOME',
        'nursingHome' => 'NURSING HOME UNDER VA CONTRACT'
      }

      KEY = {
        'burialAllowanceRequested' => {
          'checkbox' => {
            'nonService' => {
              key: 'form1[0].#subform[37].Non-Service-ConnectedDeath[0]'
            },
            'service' => {
              key: 'form1[0].#subform[37].Service-ConnectedDeath[0]'
            },
            'vaMC' => {
              key: 'form1[0].#subform[37].UnclaimedRemains[0]'
            }
          }
        },
        'amountIncurred' => {
          key: 'form1[0].#subform[37].COST_OF_BURIAL[0]',
          question: "19. EXPENSES INCURED FOR THE TRANSPORTATION OF THE VETERAN'S REMAINS FROM THE PLACE OF DEATH TO THE FINAL RESTING PLACE",
          limit: 12
        },
        'amountGovtContribution' => {
          key: 'form1[0].#subform[37].AMOUNT[0]',
          question: "18B. AMOUNT OF GOVERNMENT OR EMPLOYER CONTRIBUTION",
          limit: 10
        },
        'placeOfRemains' => {
          key: 'form1[0].#subform[37].PLACE_OF_DEATH[1]',
          limit: 80,
          question: "16. PLACE OF BURIAL OR LOCATION OF DECEASED VETERAN'S REMAINS"
        },
        'hasGovtContributions' => {
          key: 'form1[0].#subform[37].YES5[0]'
        },
        'noGovtContributions' => {
          key: 'form1[0].#subform[37].NO5[0]'
        },
        'hasStateCemetery' => {
          key: 'form1[0].#subform[37].YES4[2]'
        },
        'noStateCemetery' => {
          key: 'form1[0].#subform[37].NO4[2]'
        },
        'hasFederalCemetery' => {
          key: 'form1[0].#subform[37].YES4[0]'
        },
        'noFederalCemetery' => {
          key: 'form1[0].#subform[37].NO4[0]'
        },
        'hasBenefitsUnclaimedRemains' => {
          key: 'form1[0].#subform[37].YES4[4]'
        },
        'noBenefitsUnclaimedRemains' => {
          key: 'form1[0].#subform[37].NO4[4]'
        },
        'hasPlotAllowance' => {
          key: 'form1[0].#subform[37].YES4[1]'
        },
        'noPlotAllowance' => {
          key: 'form1[0].#subform[37].NO4[1]'
        },
        'hasBurialAllowance' => {
          key: 'form1[0].#subform[37].YES4[3]'
        },
        'noBurialAllowance' => {
          key: 'form1[0].#subform[37].NO4[3]'
        },
        'hasPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[37].YES2[0]'
        },
        'noPreviouslyReceivedAllowance' => {
          key: 'form1[0].#subform[37].NO2[0]'
        },
        'locationOfDeath' => {
          'checkbox' => {
            'vaMedicalCenter' => {
              key: 'form1[0].#subform[37].CheckBox1[1]'
            },
            'stateVeteransHome' => {
              key: 'form1[0].#subform[37].CheckBox2[1]'
            },
            'nursingHome' => {
              key: 'form1[0].#subform[37].CheckBox3[1]'
            },
            'other' => {
              key: 'form1[0].#subform[37].CheckBox4[1]'
            }
          },
          'other' => {
            key: 'form1[0].#subform[37].OTHER_SPECIFY[1]',
            question: "13B. WHERE DID THE VETERAN'S DEATH OCCUR?",
            limit: 50
          }
        },
        'burialCost' => {
          key: 'form1[0].#subform[37].COST_OF_BURIAL[1]',
          limit: 12,
          question: "13A. If VA Medical Center Death is checked, provide actual burial cost"
        },
        'veteranFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransFirstName[0]',
            limit: 12,
            question: "1. DECEASED VETERAN'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].VeteransMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].VeteransLastName[0]',
            limit: 18,
            question: "1. DECEASED VETERAN'S LAST NAME"
          }
        },
        'previousNames' => {
          key: 'form1[0].#subform[36].OTHER_NAME[0]',
          question: "12. IF VETERAN SERVED UNDER NAME OTHER THAN THAT SHOWN IN ITEM 1, GIVE FULL NAME AND SERVICE RENDERED UNDER THAT NAME",
          limit: 180
        },
        'burialDate' => {
          key: 'form1[0].#subform[36].DATE_OF_BURIAL[0]',
        },
        'vaFileNumber' => {
          key: 'form1[0].#subform[36].VAFileNumber[0]'
        },
        'placeOfDeath' => {
          key: 'form1[0].#subform[36].PLACE_OF_DEATH[0]',
          limit: 52,
          question: '10B. PLACE OF DEATH'
        },
        'claimantEmail' => {
          key: 'form1[0].#subform[36].PreferredE_MailAddress[0]',
          limit: 31,
          question: '7. PREFERRED E-MAIL ADDRESS'
        },
        'claimantFullName' => {
          'first' => {
            key: 'form1[0].#subform[36].ClaimantsFirstName[0]',
            limit: 12,
            question: "4. CLAIMANT'S FIRST NAME"
          },
          'middleInitial' => {
            key: 'form1[0].#subform[36].ClaimantsMiddleInitial1[0]'
          },
          'last' => {
            key: 'form1[0].#subform[36].ClaimantsLastName[0]',
            limit: 18,
            question: "4. CLAIMANT'S LAST NAME"
          }
        },
        'claimantAddress' => {
          'street' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_NumberAndStreet[0]',
            limit: 30,
            question: '5. CURRENT MAILING ADDRESS (No. & Street)'
          },
          'aptNum' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_City[0]',
            limit: 18,
            question: '5. CURRENT MAILING ADDRESS (City)'
          },
          'state' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_StateOrProvince[0]'
          },
          'country' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_Country[0]'
          },
          'postalCode1' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
          },
          'postalCode2' => {
            key: 'form1[0].#subform[36].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
          }
        },
        'relationship' => {
          'checkbox' => {
            'spouse' => {
              key: 'form1[0].#subform[36].CheckBox1[0]'
            },
            'child' => {
              key: 'form1[0].#subform[36].CheckBox2[0]'
            },
            'executor' => {
              key: 'form1[0].#subform[36].CheckBox4[0]'
            },
            'other' => {
              key: 'form1[0].#subform[36].CheckBox5[0]'
            },
            'parent' => {
              key: 'form1[0].#subform[36].CheckBox3[0]'
            }
          },
          'other' => {
            limit: 58,
            question: "8. RELATIONSHIP OF CLAIMANT TO DECEASED VETERAN",
            key: 'form1[0].#subform[36].OTHER_SPECIFY[0]'
          }
        },
        'toursOfDuty' => {
          limit: 3,
          first_key: 'rank',
          'dateRangeStart' => {
            key: "toursOfDuty.dateRangeStart[#{ITERATOR}]",
            question: "11A. ENTERED SERVICE (date)"
          },
          'placeOfEntry' => {
            key: "toursOfDuty.placeOfEntry[#{ITERATOR}]",
            limit: 14,
            question: "11A. ENTERED SERVICE (place)"
          },
          'serviceNumber' => {
            key: "toursOfDuty.serviceNumber[#{ITERATOR}]",
            limit: 12,
            question: '11B. SERVICE NUMBER'
          },
          'dateRangeEnd' => {
            key: "toursOfDuty.dateRangeEnd[#{ITERATOR}]",
            question: "11C. SEPARATED FROM SERVICE (date)"
          },
          'placeOfSeparation' => {
            key: "toursOfDuty.placeOfSeparation[#{ITERATOR}]",
            question: "11C. SEPARATED FROM SERVICE (place)",
            limit: 15
          },
          'rank' => {
            key: "toursOfDuty.rank[#{ITERATOR}]",
            question: "11D. GRADE, RANK OR RATING, ORGANIZATION AND BRANCH OF SERVICE",
            limit: 31
          }
        },
        "placeOfBirth" => {
          key: 'form1[0].#subform[36].PLACE_OF_BIRTH[0]',
          limit: 71,
          question: "9B. PLACE OF BIRTH"
        },
        'veteranDateOfBirth' => {
          key: 'form1[0].#subform[36].DATE_OF_BIRTH[0]'
        },
        'deathDate' => {
          key: 'form1[0].#subform[36].DATE_OF_DEATH[0]'
        },
        'claimantPhone' => {
          'first' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_AreaCode[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_FirstThreeNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].PreferredTelephoneNumber_LastFourNumbers[0]'
          }
        },
        'veteranSocialSecurityNumber2' => {
          'first' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_FirstThreeNumbers[1]'
          },
          'second' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_SecondTwoNumbers[1]'
          },
          'third' => {
            key: 'form1[0].#subform[37].VeteransSocialSecurityNumber_LastFourNumbers[1]'
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            key: 'form1[0].#subform[36].VeteransSocialSecurityNumber_LastFourNumbers[0]'
          }
        }
      }

      def split_ssn
        ssn = @form_data['veteranSocialSecurityNumber']
        return if ssn.blank?
        split_ssn = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }

        ['', '2'].each do |suffix|
          @form_data["veteranSocialSecurityNumber#{suffix}"] = split_ssn
        end

        split_ssn
      end

      def split_phone(hash, key)
        phone = hash[key]
        return if phone.blank?

        hash[key] = {
          'first' => phone[0..2],
          'second' => phone[3..5],
          'third' => phone[6..9]
        }
      end

      def extract_middle_i(hash, key)
        full_name = hash[key]
        return if full_name.blank?

        middle_name = full_name['middle']
        return if middle_name.blank?
        full_name['middleInitial'] = middle_name[0]

        hash[key]
      end

      def expand_checkbox_as_hash(hash, key)
        value = hash.try(:[], key)
        return if value.blank?

        hash['checkbox'] = {
          value => true
        }
      end

      def expand_checkbox_in_place(hash, key)
        hash.merge!(expand_checkbox(hash[key], StringHelpers.capitalize_only(key)))
      end

      def expand_relationship(hash, key)
        expand_checkbox_as_hash(hash[key], 'type')
      end

      def expand_tours_of_duty(tours_of_duty)
        return if tours_of_duty.blank?

        tours_of_duty.each do |tour_of_duty|
          expand_date_range(tour_of_duty, 'dateRange')
          tour_of_duty['rank'] = combine_hash(tour_of_duty, %w(serviceBranch rank), ', ')
        end
      end

      def expand_place_of_death
        location_of_death = @form_data['locationOfDeath']
        return if location_of_death.blank?

        location = location_of_death['location']

        @form_data['placeOfDeath'] =
          if location == 'other'
            location_of_death['other']
          else
            PLACE_OF_DEATH_KEY[location]
          end
      end

      def expand_burial_allowance
        burial_allowance = @form_data['burialAllowanceRequested']
        return if burial_allowance.blank?

        @form_data['burialAllowanceRequested'] = {
          'value' => burial_allowance
        }

        expand_checkbox_as_hash(@form_data['burialAllowanceRequested'], 'value')
      end

      def merge_fields
        %w(veteranFullName claimantFullName).each do |attr|
          extract_middle_i(@form_data, attr)
        end

        split_ssn

        split_phone(@form_data, 'claimantPhone')

        expand_relationship(@form_data, 'relationship')

        expand_place_of_death

        expand_tours_of_duty(@form_data['toursOfDuty'])

        @form_data['previousNames'] = combine_previous_names(@form_data['previousNames'])

        expand_burial_allowance

        expand_checkbox_as_hash(@form_data['locationOfDeath'], 'location')

        %w(
          previouslyReceivedAllowance
          burialAllowance
          plotAllowance
          benefitsUnclaimedRemains
          federalCemetery
          stateCemetery
          govtContributions
        ).each do |attr|
          expand_checkbox_in_place(@form_data, attr)
        end

        @form_data
      end
    end
  end
end
