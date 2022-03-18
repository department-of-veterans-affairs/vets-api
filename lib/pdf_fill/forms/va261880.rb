# frozen_string_literal: true

module PdfFill
  module Forms
    class Va261880 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'fullName' =>
        {
          key: 'form1[0].#subform[0].NameOfVeteran[0]',
          limit: 40,
          question_num: 1,
          question_text: 'NAME OF VETERAN'
        },
        'dateOfBirth' =>
        {
          key: 'form1[0].#subform[0].DateofBirth[0]',
          limit: 10,
          question_num: 2,
          question_suffix: 'A',
          question_text: 'DATE OF BIRTH'
        },
        'contactPhone' =>
        {
          key: 'form1[0].#subform[0].DaytimePhoneNumber[0]',
          limit: 10,
          question_num: 5,
          question_suffix: 'A',
          question_text: 'PHONE NUMBER'
        },
        'contactEmail' =>
        {
          key: 'form1[0].#subform[0].EmailAddress_IfApplicable[0]',
          limit: 30,
          question_num: 6,
          question_suffix: 'A',
          question_text: 'E-MAIL ADDRESS OF CLAIMANT'
        },
        'applicantAddress' =>
        {
          key: 'form1[0].#subform[0].Address_NumberandStreetorRuralRoute_City_or_PO_State_ZIPCode[0]',
          limit: 50,
          question_num: 7,
          question_text: 'ADDRESS'
        },
        'identity' =>
        {
          key: 'form1[0].#subform[0].RadioButtonList[1]'
        },
        'periodsOfService' =>
        {
          limit: 3,
          first_key: 'militaryBranch',
          'militaryBranch' =>
          {
            key: 'form1[0].#subform[0].BranchOfService[%iterator%]',
            limit: 20,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'BRANCH OF SERVICE'
          },
          'dateRangeFrom' =>
          {
            key: 'form1[0].#subform[0].DateEntered[%iterator%]',
            limit: 14,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'DATE ENTERED'
          },
          'dateRangeTo' =>
          {
            key: 'form1[0].#subform[0].DateSeparated[%iterator%]',
            limit: 14,
            question_num: 9,
            question_suffix: 'C',
            question_text: 'DATE SEPARATED'
          }
        },
        'periodsOfServiceReserveGuard' =>
        {
          limit: 3,
          first_key: 'militaryBranch',
          'militaryBranch' =>
          {
            key: 'form1[0].#subform[0].BranchOfServiceReserveGuard[%iterator%]',
            limit: 20,
            question_num: 9,
            question_suffix: 'D',
            question_text: 'BRANCH OF SERVICE'
          },
          'dateRangeFrom' => {
            key: 'form1[0].#subform[0].DateEnteredReserveGuard[%iterator%]',
            limit: 14,
            question_num: 9,
            question_suffix: 'D',
            question_text: 'DATE ENTERED'
          },
          'dateRangeTo' => {
            key: 'form1[0].#subform[0].DateSeparatedReserveGuard[%iterator%]',
            limit: 14,
            question_num: 9,
            question_suffix: 'D',
            question_text: 'DATE SEPARATED'
          }
        },
        'vaLoanIndicator' =>
        {
          'vaLoanIndicatorYes' =>
          {
            key: 'form1[0].#subform[0].RadioButtonListYes[2]',
            question_num: 10,
            question_suffix: 'A'
          },
          'vaLoanIndicatorNo' =>
          {
            key: 'form1[0].#subform[0].RadioButtonListNo[2]',
            question_num: 10,
            question_suffix: 'A'
          },
          'vaLoanIndicatorNever' =>
          {
            key: 'form1[0].#subform[0].RadioButtonListNA[2]',
            question_num: 10,
            question_suffix: 'A'
          }
        },
        'relevantPriorLoans' =>
        {
          limit: 2,
          first_key: 'dateRange',
          'dateRange' =>
          {
            key: 'form1[0].#subform[0].DateofVaLoan[%iterator%]',
            question_num: 10,
            question_suffix: 'B',
            question_text: 'Date of Loan'
          },
          'propertyAddress' =>
          {
            key: 'form1[0].#subform[0].StreetAddressVaLoan[%iterator%]',
            question_num: 10,
            question_suffix: 'C',
            question_text: 'Property Address of Loan'
          },
          'propertyCity' =>
          {
            key: 'form1[0].#subform[0].CityandStateVaLoan[%iterator%]',
            question_num: 10,
            question_suffix: 'D',
            question_text: 'City State of Loan'
          }
        },
        'resortationIntent' =>
        {
          key: 'form1[0].#subform[0].RadioButtonList[3]',
          question_num: 11,
          question_suffix: 'A'
        },
        'relevantPriorLoansResortation' =>
        {
          limit: 1,
          first_key: 'dateRange',
          'dateRange' =>
          {
            key: 'form1[0].#subform[0].DateofLoanRest[%iterator%]',
            question_num: 11,
            question_suffix: 'B',
            question_text: 'Date of Loan'
          },
          'propertyAddress' =>
          {
            key: 'form1[0].#subform[0].StreetAddressRest[%iterator%]',
            question_num: 11,
            question_suffix: 'C',
            question_text: 'Address of Loan'
          },
          'propertyCity' =>
          {
            key: 'form1[0].#subform[0].CityandStateRest[%iterator%]',
            question_num: 11,
            question_suffix: 'D',
            question_text: 'City and State of Loan'
          }
        },
        'cashOutIntent' =>
        {
          key: 'form1[0].#subform[0].RadioButtonList[4]',
          question_num: 12,
          question_suffix: 'A'
        },
        'relevantPriorLoansCashOut' =>
        {
          limit: 1,
          first_key: 'dateRange',
          'dateRange' =>
          {
            key: 'form1[0].#subform[0].DateofLoanCashOut[0]',
            question_num: 12,
            question_suffix: 'B',
            question_text: 'Date of Loan'
          },
          'propertyAddress' =>
          {
            key: 'form1[0].#subform[0].StreetAddressCashOut[%iterator%]',
            question_num: 12,
            question_suffix: 'C',
            question_text: 'Address of Loan'
          },
          'propertyCity' =>
          {
            key: 'form1[0].#subform[0].CityandStateCashOut[%iterator%]',
            question_num: 13,
            question_suffix: 'D',
            question_text: 'City and State of Loan'
          }
        },
        'lowerRateIntent' =>
        {
          key: 'form1[0].#subform[0].RadioButtonList[5]',
          question_num: 13,
          question_suffix: 'A'
        },
        'relevantPriorLoansLowerRate' =>
        {
          limit: 1,
          first_key: 'dateRange',
          'dateRange' =>
          {
            key: 'form1[0].#subform[0].DateofLoanIRRRL[0]',
            question_num: 13,
            question_suffix: 'B',
            question_text: 'Date of Loan'
          },
          'propertyAddress' =>
          {
            key: 'form1[0].#subform[0].StreetAddressIRRRL[0]',
            question_num: 13,
            question_suffix: 'C',
            question_text: 'Address of Loan'
          },
          'propertyCity' =>
          {
            key: 'form1[0].#subform[0].CityandStateIRRRL[0]',
            question_num: 13,
            question_suffix: 'D',
            question_text: 'City and State of Loan'
          }
        },
        'signature' =>
        {
          key: 'form1[0].#subform[0].TextField1[2]',
          limit: 25,
          question_num: 14,
          question_suffix: 'A',
          question_text: 'SIGNATURE OF VETERAN'
        },
        'date_signed' =>
        {
          key: 'form1[0].#subform[0].DateTimeField1[0]',
          limit: 14,
          question_num: 14,
          question_suffix: 'B',
          question_text: 'DATE SIGNED'
        }
      }.freeze

      def merge_fields(_options = {})
        merge_veteran_name_helpers
        merge_address_helpers
        map_service_date_helpers
        resolve_reserve_guard
        resolve_checkboxes
        @form_data['fullName'] = @full_name
        @form_data['applicantAddress'] = @address

        @form_data['signature'] = @full_name
        @form_data['date_signed'] = Time.zone.today.to_s if @full_name.present?

        @form_data
      end

      def merge_veteran_name_helpers
        @full_name = combine_hash(@form_data['fullName'], %w[firstName middleName lastName suffixName])
      end

      def merge_address_helpers
        @address = combine_hash(@form_data['applicantAddress'],
                                %w[street street2 street3 city state postalCode country])
      end

      def map_service_date_helpers
        @form_data['periodsOfService'].each do |period|
          period['dateRangeFrom'] = Hash.new(0)
          period['dateRangeFrom'] = period['dateRange']['from']
          period['dateRangeTo'] = Hash.new(0)
          period['dateRangeTo'] = period['dateRange']['to']
        end
      end

      def resolve_reserve_guard
        @form_data['periodsOfServiceReserveGuard'] = Hash.new { |h, k| h[k] = [] }
        array_reserve_guard, array_init = @form_data['periodsOfService'].partition do |x|
          x['militaryBranch'].include?('National') ||
            x['militaryBranch'].include?('Reserve') ||
            x['militaryBranch'].include?('Other')
        end
        @form_data['periodsOfServiceReserveGuard'] = array_reserve_guard
        @form_data['periodsOfService'].clear
        @form_data['periodsOfService'] = array_init
      end

      def resolve_checkboxes
        set_default_checkboxes
        previous_loan = @form_data['vaLoanIndicator']
        property_owned = @form_data['propertyOwned']
        if previous_loan && property_owned.nil?
          @form_data['vaLoanIndicator'] = {
            'vaLoanIndicatorYes' => 0
          }
        elsif previous_loan && !property_owned.nil?
          @form_data['vaLoanIndicator'] = {
            'vaLoanIndicatorNo' => 1
          }
        elsif !previous_loan && !previous_loan.nil?
          @form_data['vaLoanIndicator'] = {
            'vaLoanIndicatorNever' => 2
          }
        end

        veteran_status = @form_data['identity']
        @form_data['identity'] = 2 unless veteran_status.nil?
        @form_data['identity'] = 1 if veteran_status == 'ADSM'

        expand_prior_loan_data
      end

      def set_default_checkboxes
        @form_data['resortationIntent'] = 2
        @form_data['cashOutIntent'] = 2
        @form_data['lowerRateIntent'] = 2
      end

      # rubocop:disable Metrics/MethodLength
      # rubocop:disable Layout/LineLength
      def expand_prior_loan_data
        start_finish_range = ''
        prior_loan_array = @form_data['relevantPriorLoans']

        if prior_loan_array.present?
          prior_loan_array.each do |i|
            split_start = i['dateRange']['startDate'].split('-')
            split_paid = i['dateRange']['paidOffDate'].split('-')
            date_range = "#{split_start[1]}-#{split_start[0]} to #{+ split_paid[1]}-#{split_paid[0]}"

            start_finish_range = date_range
            i['dateRange'] = start_finish_range

            loan_street_address =
              "#{i['propertyAddress']['propertyAddress1']} #{i['propertyAddress']['propertyAddress2']}"
            loan_city_address =
              "#{i['propertyAddress']['propertyCity']} #{i['propertyAddress']['propertyState']} #{i['propertyAddress']['propertyZip']}"

            i['propertyAddress'] = ''
            i['propertyAddress'] = loan_street_address
            i['propertyCity'] = ''
            i['propertyCity'] = loan_city_address
          end

          intent = @form_data['intent']
          case intent
          when 'ONETIMERESTORATION'
            @form_data['resortationIntent'] = 1
            dup_array('relevantPriorLoansResortation', prior_loan_array)
          when 'REFI'
            @form_data['cashOutIntent'] = 1
            dup_array('relevantPriorLoansCashOut', prior_loan_array)
          when 'IRRRL'
            @form_data['lowerRateIntent'] = 1
            dup_array('relevantPriorLoansLowerRate', prior_loan_array)
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
      # rubocop:enable Layout/LineLength

      def dup_array(type, array)
        @form_data[type] = Hash.new { |h, k| h[k] = [] }
        @form_data[type] = array.deep_dup
      end
    end
  end
end
