# frozen_string_literal: true

module PdfFill
  module Forms
    class Va210538 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'dependencyVerification' => {
          'veteranInformation' => {
            'fullName' => {
              'first' => {
                key: 'Veterans_First_Name[0]',
                limit: 12,
                question_num: 1,
                question_suffix: 'A',
                question_text: 'VETERAN\'S NAME'
              },
              'middleInitial' => {
                key: 'form1[0].#subform[0].Middle_Initial1[0]',
                limit: 1,
                question_num: 1,
                question_suffix: 'B',
                question_text: 'VETERAN\'S NAME'
              },
              'last' => {
                key: 'form1[0].#subform[0].Last_Name[0]',
                limit: 18,
                question_num: 1,
                question_suffix: 'C',
                question_text: 'VETERAN\'S NAME'
              }
            }, # end fullName
            'ssn' => {
              'first' => {
                key: 'form1[0].#subform[0].Social_Security_Number_FirstThreeNumbers[0]',
                limit: 3,
                question_num: 2,
                question_suffix: 'A',
                question_text: 'SOCIAL SECURITY NUMBER'
              },
              'second' => {
                key: 'form1[0].#subform[0].Social_Security_Number_SecondTwoNumbers[0]',
                limit: 2,
                question_num: 2,
                question_suffix: 'B',
                question_text: 'SOCIAL SECURITY NUMBER'
              },
              'third' => {
                key: 'form1[0].#subform[0].Social_Security_Number_LastFourNumbers[0]',
                limit: 4,
                question_num: 2,
                question_suffix: 'C',
                question_text: 'SOCIAL SECURITY NUMBER'
              }
            },
            'ssn2' => {
              'first' => {
                key: 'Social_Security_Number_FirstThreeNumbers[1]'
              },
              'second' => {
                key: 'Social_Security_Number_SecondTwoNumbers[1]'
              },
              'third' => {
                key: 'Social_Security_Number_LastFourNumbers[1]'
              }
            },
            'VAFileNumber' => {
              key: 'form1[0].#subform[0].VA_File_Number[0]',
              limit: 9,
              question_num: 3,
              question_suffix: 'A',
              question_text: 'VA FILE NUMBER'
            },
            'dateOfBirth' => {
              'month' => {
                key: 'form1[0].#subform[0].DOB_Month[0]',
                limit: 2,
                question_num: 4,
                question_suffix: 'A',
                question_text: 'DATE OF BIRTH'
              },
              'day' => {
                key: 'form1[0].#subform[0].DOB_Day[0]',
                limit: 2,
                question_num: 4,
                question_suffix: 'B',
                question_text: 'DATE OF BIRTH'
              },
              'year' => {
                key: 'form1[0].#subform[0].DOB_Year[0]',
                limit: 4,
                question_num: 4,
                question_suffix: 'C',
                question_text: 'DATE OF BIRTH'
              }
            }
          }, # end veteran_information
          'email1' => {
            key: 'form1[0].#subform[0].E-Mail_Address[0]',
            limit: 18,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'E-MAIL ADDRESS OF CLAIMANT'
          },
          'email2' => {
            key: 'form1[0].#subform[0].E-Mail_Address[1]',
            limit: 18,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'E-MAIL ADDRESS OF CLAIMANT'
          },
          'updateDiaries' => {
            'status_changed_yes' => { key: 'form1[0].#subform[0].YES_CHECKBOX1[0]' },
            'status_changed_no' => { key: 'form1[0].#subform[0].NO_CHECKBOX1[0]' }
          }
        },
        'signature' => {
          key: 'signature'
        },
        'dateSigned' => {
          'month' => {
            key: 'form1[0].#subform[1].#subform[2].Date_Signed_Month[0]'
          },
          'day' => {
            key: 'form1[0].#subform[1].#subform[2].Date_Signed_Day[0]'
          },
          'year' => {
            key: 'form1[0].#subform[1].#subform[2].Date_Signed_Year[0]'
          }
        } # end date_signed
      }.freeze

      def merge_fields(_options = {})
        merge_veteran_helpers

        expand_signature(@form_data['dependencyVerification']['veteranInformation']['fullName'])
        @form_data['dateSigned'] = split_date(@form_data['signatureDate'])

        @form_data
      end

      def merge_veteran_helpers
        veteran_information = @form_data['dependencyVerification']['veteranInformation']
        # extract middle initial
        veteran_information['fullName'] = extract_middle_i(veteran_information, 'fullName')

        # extract ssn
        ssn = veteran_information['ssn']
        veteran_information['ssn'] = split_ssn(ssn.delete('-')) if ssn.present?
        veteran_information['ssn2'] = split_ssn(ssn.delete('-')) if ssn.present?

        # extract birth date
        veteran_information['dateOfBirth'] = split_date(veteran_information['dateOfBirth'])

        # extract email address
        extract_email

        # this is confusing but if updateDiaries is set to true
        # that means the status of the dependents has NOT changed
        update_diaries = @form_data['dependencyVerification']['updateDiaries']
        @form_data['dependencyVerification']['updateDiaries'] = {
          'status_changed_yes' => select_checkbox(!update_diaries),
          'status_changed_no' => select_checkbox(update_diaries)
        }
      end

      def extract_email
        email_address = @form_data['dependencyVerification']['veteranInformation']['email']
        return if email_address.blank?

        if email_address.length > 17 && email_address.length < 37
          @form_data['dependencyVerification']['email1'] = email_address[0..17]
          @form_data['dependencyVerification']['email2'] = email_address[18..]
        else
          @form_data['dependencyVerification']['email1'] = email_address
        end
      end
    end
  end
end
