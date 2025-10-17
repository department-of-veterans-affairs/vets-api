# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/forms/form_helper'

module PdfFill
  module Forms
    # rubocop:disable Metrics/ClassLength
    class Va214192 < FormBase
      include FormHelper

      KEY = {
        'veteranInformation' => {
          'fullName' => {
            'first' => {
              key: 'F[0].Page_1[0].Veterans_First_Name[0]',
              limit: 12,
              question_num: 3,
              question_text: 'VETERAN/BENEFICIARY\'S FIRST NAME'
            },
            'middle' => {
              key: 'F[0].Page_1[0].Middle_Initial1[0]',
              limit: 1
            },
            'last' => {
              key: 'F[0].Page_1[0].Last_Name[0]',
              limit: 18
            }
          },
          'ssn' => {
            'first' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3
            },
            'second' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2
            },
            'third' => {
              key: 'F[0].Page_1[0].SocialSecurityNumber_LastFourNumbers[0]',
              limit: 4
            }
          },
          'ssnPage2' => {
            'first' => {
              key: 'F[0].#subform[1].SocialSecurityNumber_FirstThreeNumbers[0]',
              limit: 3
            },
            'second' => {
              key: 'F[0].#subform[1].SocialSecurityNumber_SecondTwoNumbers[0]',
              limit: 2
            },
            'third' => {
              key: 'F[0].#subform[1].SocialSecurityNumber_LastFourNumbers[0]',
              limit: 4
            }
          },
          'vaFileNumber' => {
            key: 'F[0].Page_1[0].VA_File_Number_If_Applicable[0]',
            limit: 9
          },
          'dateOfBirth' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[0]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[0]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[0]',
              limit: 4
            }
          }
        },
        'employmentInformation' => {
          'employerNameAndAddress' => {
            key: 'F[0].Page_1[0].nameandaddress[0]'
          },
          'returnAddress' => {
            key: 'F[0].Page_1[0].completeaddress[0]'
          },
          'typeOfWorkPerformed' => {
            key: 'F[0].Page_1[0].TypeOfWork[0]'
          },
          'beginningDateOfEmployment' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[1]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[1]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[1]',
              limit: 4
            }
          },
          'endingDateOfEmployment' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[2]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[2]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[2]',
              limit: 4
            }
          },
          'amountEarnedLast12Months' => {
            'thousands' => {
              key: 'F[0].Page_1[0].ThousandsDollarAmount[0]',
              limit: 3
            },
            'hundreds' => {
              key: 'F[0].Page_1[0].HundredsDollarAmount[0]',
              limit: 3
            },
            'cents' => {
              key: 'F[0].Page_1[0].CentsAmount[0]',
              limit: 2
            }
          },
          'timeLostLast12MonthsOfEmployment' => {
            key: 'F[0].Page_1[0].timelost[0]'
          },
          'hoursWorkedDaily' => {
            key: 'F[0].Page_1[0].NumberHoursWorkedDaily[0]',
            limit: 3
          },
          'hoursWorkedWeekly' => {
            key: 'F[0].Page_1[0].NumberHoursWorkedWeekly[0]',
            limit: 3
          },
          'concessions' => {
            key: 'F[0].Page_1[0].Concessions[0]'
          },
          'terminationReason' => {
            key: 'F[0].Page_1[0].ReasonVeteranNotWorking[0]'
          },
          'dateLastWorked' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[4]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[4]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[4]',
              limit: 4
            }
          },
          'lastPaymentDate' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[3]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[3]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[3]',
              limit: 4
            }
          },
          'lastPaymentGrossAmount' => {
            key: 'F[0].Page_1[0].grossamount[0]'
          },
          'lumpSumPaymentMade' => {
            key: 'F[0].Page_1[0].RadioButtonList[0]'
          },
          'grossAmountPaid' => {
            key: 'F[0].Page_1[0].grossamount[1]'
          },
          'datePaid' => {
            'month' => {
              key: 'F[0].Page_1[0].DOBmonth[5]',
              limit: 2
            },
            'day' => {
              key: 'F[0].Page_1[0].DOBday[5]',
              limit: 2
            },
            'year' => {
              key: 'F[0].Page_1[0].DOByear[5]',
              limit: 4
            }
          }
        },
        'militaryDutyStatus' => {
          'currentDutyStatus' => {
            key: 'F[0].Page_1[0].VeteransCurrentDutyStatus[0]'
          },
          'veteranDisabilitiesPreventMilitaryDuties' => {
            key: 'F[0].Page_1[0].RadioButtonList[1]'
          }
        },
        'benefitEntitlementPayments' => {
          'sickRetirementOtherBenefits' => {
            key: 'F[0].#subform[1].RadioButtonList[0]'
          },
          'typeOfBenefit' => {
            key: 'F[0].#subform[1].TYPEOFBENEFIT[0]'
          },
          'grossMonthlyAmountOfBenefit' => {
            'thousands' => {
              key: 'F[0].#subform[1].ThousandsDollarAmount[0]',
              limit: 3
            },
            'hundreds' => {
              key: 'F[0].#subform[1].HundredsDollarAmount[0]',
              limit: 3
            },
            'cents' => {
              key: 'F[0].#subform[1].CentsAmount[0]',
              limit: 2
            }
          },
          'dateBenefitBegan' => {
            'month' => {
              key: 'F[0].#subform[1].DOBmonth[0]',
              limit: 2
            },
            'day' => {
              key: 'F[0].#subform[1].DOBday[0]',
              limit: 2
            },
            'year' => {
              key: 'F[0].#subform[1].DOByear[0]',
              limit: 4
            }
          },
          'dateFirstPaymentIssued' => {
            'month' => {
              key: 'F[0].#subform[1].DOBmonth[1]',
              limit: 2
            },
            'day' => {
              key: 'F[0].#subform[1].DOBday[1]',
              limit: 2
            },
            'year' => {
              key: 'F[0].#subform[1].DOByear[1]',
              limit: 4
            }
          },
          'dateBenefitWillStop' => {
            'month' => {
              key: 'F[0].#subform[1].DOBmonth[2]',
              limit: 2
            },
            'day' => {
              key: 'F[0].#subform[1].DOBday[2]',
              limit: 2
            },
            'year' => {
              key: 'F[0].#subform[1].DOByear[2]',
              limit: 4
            }
          },
          'remarks' => {
            key: 'F[0].#subform[1].TYPEOFBENEFIT[1]'
          }
        },
        'employerCertification' => {
          'certificationDate' => {
            key: 'F[0].#subform[1].DateSigned[0]'
          },
          'signature' => {
            key: 'F[0].#subform[1].Digital_Signature[0]'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        merge_veteran_info
        merge_employment_info
        merge_military_duty
        merge_benefits
        merge_certification
        @form_data
      end

      private

      def merge_veteran_info
        return unless @form_data['veteranInformation']

        vet_info = @form_data['veteranInformation']
        merge_ssn_fields(vet_info)
        merge_date_of_birth(vet_info)
      end

      def merge_ssn_fields(vet_info)
        return unless vet_info['ssn']

        ssn = vet_info['ssn'].to_s.gsub(/\D/, '')
        ssn_parts = {
          'first' => ssn[0..2],
          'second' => ssn[3..4],
          'third' => ssn[5..8]
        }
        # Populate SSN on both page 1 and page 2
        @form_data['veteranInformation']['ssn'] = ssn_parts
        @form_data['veteranInformation']['ssnPage2'] = ssn_parts
      end

      def merge_date_of_birth(vet_info)
        return unless vet_info['dateOfBirth']

        dob = parse_date(vet_info['dateOfBirth'])
        return unless dob

        @form_data['veteranInformation']['dateOfBirth'] = {
          'month' => dob[:month],
          'day' => dob[:day],
          'year' => dob[:year]
        }
      end

      def merge_employment_info
        return unless @form_data['employmentInformation']

        emp_info = @form_data['employmentInformation']
        merge_employer_address(emp_info)
        merge_employment_dates(emp_info)
        merge_amount_earned(emp_info)
        merge_radio_buttons(emp_info)
      end

      def merge_employer_address(emp_info)
        return unless emp_info['employerName'] || emp_info['employerAddress']

        name_and_addr = []
        name_and_addr << emp_info['employerName'] if emp_info['employerName']
        if emp_info['employerAddress']
          addr = emp_info['employerAddress']
          name_and_addr << addr['street'] if addr['street']
          name_and_addr << addr['street2'] if addr['street2']
          name_and_addr << "#{addr['city']}, #{addr['state']} #{addr['postalCode']}" if addr['city']
        end
        @form_data['employmentInformation']['employerNameAndAddress'] = name_and_addr.join("\n")
      end

      def merge_employment_dates(emp_info)
        %w[beginningDateOfEmployment endingDateOfEmployment dateLastWorked lastPaymentDate
           datePaid].each do |date_field|
          next unless emp_info[date_field]

          parsed = parse_date(emp_info[date_field])
          next unless parsed

          @form_data['employmentInformation'][date_field] = {
            'month' => parsed[:month],
            'day' => parsed[:day],
            'year' => parsed[:year]
          }
        end
      end

      def merge_amount_earned(emp_info)
        return unless emp_info['amountEarnedLast12Months']

        amount = emp_info['amountEarnedLast12Months'].to_f
        dollars = amount.floor
        cents = ((amount - dollars) * 100).round

        thousands = (dollars / 1000).floor
        hundreds = dollars % 1000

        amount_parts = {
          'thousands' => thousands.to_s.rjust(3, '0'),
          'hundreds' => hundreds.to_s.rjust(3, '0'),
          'cents' => cents.to_s.rjust(2, '0')
        }
        @form_data['employmentInformation']['amountEarnedLast12Months'] = amount_parts
      end

      def merge_radio_buttons(emp_info)
        return unless emp_info.key?('lumpSumPaymentMade')

        @form_data['employmentInformation']['lumpSumPaymentMade'] = emp_info['lumpSumPaymentMade'] ? 'YES' : 'NO'
      end

      def merge_military_duty
        return unless @form_data['militaryDutyStatus']

        # Convert boolean to YES/NO for radio button
        if @form_data['militaryDutyStatus'].key?('veteranDisabilitiesPreventMilitaryDuties')
          prevents = @form_data['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties']
          @form_data['militaryDutyStatus']['veteranDisabilitiesPreventMilitaryDuties'] = prevents ? 'YES' : 'NO'
        end
      end

      def merge_benefits
        return unless @form_data['benefitEntitlementPayments']

        benefits = @form_data['benefitEntitlementPayments']
        merge_benefit_radio_buttons(benefits)
        merge_benefit_amount(benefits)
        merge_benefit_dates(benefits)
      end

      def merge_benefit_radio_buttons(benefits)
        return unless benefits.key?('sickRetirementOtherBenefits')

        @form_data['benefitEntitlementPayments']['sickRetirementOtherBenefits'] =
          benefits['sickRetirementOtherBenefits'] ? 'YES' : 'NO'
      end

      def merge_benefit_amount(benefits)
        return unless benefits['grossMonthlyAmountOfBenefit']

        amount = benefits['grossMonthlyAmountOfBenefit'].to_f
        dollars = amount.floor
        cents = ((amount - dollars) * 100).round

        thousands = (dollars / 1000).floor
        hundreds = dollars % 1000

        @form_data['benefitEntitlementPayments']['grossMonthlyAmountOfBenefit'] = {
          'thousands' => thousands.to_s.rjust(3, '0'),
          'hundreds' => hundreds.to_s.rjust(3, '0'),
          'cents' => cents.to_s.rjust(2, '0')
        }
      end

      def merge_benefit_dates(benefits)
        %w[dateBenefitBegan dateFirstPaymentIssued dateBenefitWillStop].each do |date_field|
          next unless benefits[date_field]

          parsed = parse_date(benefits[date_field])
          next unless parsed

          @form_data['benefitEntitlementPayments'][date_field] = {
            'month' => parsed[:month],
            'day' => parsed[:day],
            'year' => parsed[:year]
          }
        end
      end

      def merge_certification
        return unless @form_data['employerCertification']

        cert = @form_data['employerCertification']

        # Format certification date (expecting MM/DD/YYYY format)
        if cert['certificationDate']
          date = parse_date(cert['certificationDate'])
          if date
            @form_data['employerCertification']['certificationDate'] = "#{date[:month]}/#{date[:day]}/#{date[:year]}"
          end
        end
      end

      def parse_date(date_string)
        return nil unless date_string

        date = Date.parse(date_string.to_s)
        {
          month: date.month.to_s.rjust(2, '0'),
          day: date.day.to_s.rjust(2, '0'),
          year: date.year.to_s
        }
      rescue ArgumentError
        nil
      end
    end
    # rubocop:enable Metrics/ClassLength
  end
end
