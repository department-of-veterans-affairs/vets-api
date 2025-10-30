# frozen_string_literal: true

require 'employment_questionairres/pdf_fill/section'

module EmploymentQuestionairres
  module PdfFill
    # Section I: Veteran's Identification Information
    class Section1 < Section
      include Helpers
      include ::PdfFill::Forms::FormHelper
      include ::PdfFill::Forms::FormHelper::PhoneNumberFormatting

      FIELDS = {
        veteranFullName: {
          first: 'John',
          middle: 'A',
          last: 'Doe'
        },
        veteranSocialSecurityNumber: '122330203',
        vaFileNumber: 'C12345678',
        dateOfBirth: '1975-03-15',
        veteranAddress: {
          street: '123 Main Street',
          apartment: '5B',
          city: 'Springfield',
          state: 'IL',
          postalCode: '234562323',
          country: 'USA'
        },
        veteranServiceNumer: '1234567',
        veteranContact: {
          email: 'john.doe@example.com',
          primaryPhone: '2175551234',
          alternatePhone: '2175555678'
        },
        employmentStatus: {
          radio: '0',
          date_mailed: '2025-10-15'
        },
        signatureSection1: {
          date_signed: '2025-10-15',
          veteranSocialSecurityNumber: '123456789'
        },
        employmentHistory: [
          {
            nameAndAddress: 'ACME Corp, 456 Industrial Ave, Springfield, IL',
            typeOfWork: 'Construction Worker',
            timeLost: '2 weeks',
            hoursPerWeek: '40',
            dateRange: {
              from: '04/04/2020',
              to: '06/20/2020'
            },
            grossEarningsPerMonth: '3500'
          },
          {
            nameAndAddress: '11 Name And Address 1',
            typeOfWork: 'Construction',
            hoursPerWeek: 10,
            dateRange: {
              from: '04/04/2020',
              to: '06/20/2020'
            },
            timeLost: '40',
            grossEarningsPerMonth: '1000'
          },
          {
            nameAndAddress: '33 Name And Address 1',
            typeOfWork: 'Construction',
            hoursPerWeek: 30,
            dateRange: {
              from: '04/04/2020',
              to: '06/20/2020'
            },
            timeLost: '40',
            grossEarningsPerMonth: '4000'
          },
          {
            nameAndAddress: '43 Name And Address 1',
            typeOfWork: 'Construction',
            hoursPerWeek: 30,
            dateRange: {
              from: '04/04/2020',
              to: '06/20/2020'
            },
            timeLost: '40',
            grossEarningsPerMonth: '5000'
          }
        ],
        signatureSection2: {
          signatureDate: '2025-10-15'
        },
        stationAddress: {
          address: '123 Veterans Affairs Office, Springfield, IL 62704'
        }
      }.freeze

      # Section configuration hash
      KEY = {
        'veteranFullName' => {
          'first' => {
            limit: 12,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranFirstName[0]'
          },
          'middle' => {
            limit: 1,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranMiddleInitial1[0]'
          },
          'last' => {
            limit: 18,
            question_num: 1,
            key: 'F[0].Page_1[0].VeteranLastName[0]'
          }
        },
        'veteranSocialSecurityNumber' => {
          'first' => {
            limit: 3,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_FirstThreeNumbers[0]'
          },
          'second' => {
            limit: 2,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_SecondTwoNumbers[0]'
          },
          'third' => {
            limit: 4,
            question_num: 2,
            key: 'F[0].Page_1[0].Veterans_Social_SecurityNumber_LastFourNumbers[0]'
          }
        },
        'vaFileNumber' => {
          question_num: 3,
          limit: 9,
          key: 'F[0].Page_1[0].VAFileNumber[0]'
        },
        'dateOfBirth' => {
          'month' => {
            limit: 2,
            question_num: 4,
            key: 'F[0].Page_1[0].DOBmonth[0]'
          },
          'day' => {
            limit: 2,
            question_num: 4,
            key: 'F[0].Page_1[0].DOBday[0]'
          },
          'year' => {
            limit: 4,
            question_num: 4,
            key: 'F[0].Page_1[0].DOByear[0]'
          }
        },
        'veteranServiceNumer' => {
          limit: 9,
          question_num: 5,
          key: 'F[0].Page_1[0].VeteransServiceNumber[0]'
        },
        'veteranContact' => {
          'email' => {
            limit: 50,
            question_num: 6,
            key: 'F[0].Page_1[0].E-Mail_Address[0]'
          },
          'primaryPhone' => {
            limit: 10,
            question_num: 7,
            key: 'F[0].Page_1[0].PrimaryTelephoneNumber[0]'
          },
          'alternatePhone' => {
            limit: 10,
            question_num: 8,
            key: 'F[0].Page_1[0].AlternateTelephoneNumber[0]'
          }
        },
        'veteranAddress' => {
          'street' => {
            limit: 30,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_NumberAndStreet[0]'
          },
          'apartment' => {
            limit: 5,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_ApartmentOrUnitNumber[0]'
          },
          'city' => {
            limit: 20,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_City[0]'
          },
          'state' => {
            limit: 2,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_StateOrProvince[0]'
          },
          'postalCode' => {
            'firstFive' => {
              limit: 5,
              question_num: 9,
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_FirstFiveNumbers[0]'
            },
            'lastFour' => {
              limit: 5,
              question_num: 9,
              key: 'F[0].Page_1[0].CurrentMailingAddress_ZIPOrPostalCode_LastFourNumbers[0]'
            }
          },
          'country' => {
            limit: 20,
            question_num: 9,
            key: 'F[0].Page_1[0].CurrentMailingAddress_Country[0]'
          }
        }
      }.freeze

      def expand(form_data = {})
        split_data(form_data)

        form_data
      end

      def split_data(form_data)
        form_data['dateOfBirth'] = split_date(form_data['dateOfBirth'])
        form_data['veteranAddress']['postalCode'] = split_postal_code(form_data['veteranAddress'])
        form_data['veteranSocialSecurityNumber'] = split_ssn(form_data['veteranSocialSecurityNumber'])

        form_data
      end
    end
  end
end
