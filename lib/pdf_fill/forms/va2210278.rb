# frozen_string_literal: true

require 'pdf_fill/forms/form_base'
require 'pdf_fill/form_value'

module PdfFill
  module Forms
    class Va2210278 < FormBase
      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'claimantPersonalInformation' => {
          'fullName' => {
            key: 'fullName',
            limit: 31,
            question_num: 1,
            question_suffix: 'A',
            question_text: 'NAME OF CLAIMANT'
          },
          'ssn' => {
            key: 'ssn',
            limit: 10,
            question_num: 2,
            question_suffix: 'A',
            question_text: 'SOCIAL SECURITY NUMBER'
          },
          'vaFileNumber' => {
            key: 'vaFileNumber',
            limit: 9,
            question_num: 3,
            question_suffix: 'A',
            question_text: 'VA FILE NUMBER'
          },
          'dateOfBirth' => {
            key: 'dateOfBirth',
            limit: 20,
            question_num: 4,
            question_suffix: 'A',
            question_text: 'DATE OF BIRTH'
          }
        },
        'claimantAddress' => {
          key: 'claimantAddress',
          limit: 500,
          question_num: 5,
          question_suffix: 'A',
          question_text: 'CLAIMANT ADDRESS'
        },
        'claimantContactInformation' => {
          'phoneNumber' => {
            key: 'phoneNumber',
            limit: 13,
            question_num: 6,
            question_suffix: 'A',
            question_text: 'PHONE NUMBER'
          },
          'emailAddress' => {
            key: 'emailAddress',
            limit: 30,
            question_num: 7,
            question_suffix: 'A',
            question_text: 'EMAIL ADDRESS'
          }
        },
        'thirdPartyPersonName' => {
          key: 'thirdPartyPersonName',
          limit: 12,
          question_num: 8,
          question_suffix: 'A',
          question_text: 'NAME OF PERSON TO RECEIVE INFORMATION'
        },
        'thirdPartyPersonAddress' => {
          key: 'thirdPartyPersonAddress',
          limit: 500,
          question_num: 9,
          question_suffix: 'A',
          question_text: 'ADDRESS OF PERSON TO RECEIVE INFORMATION'
        },
        'thirdPartyOrganizationInformation' => {
          'organizationName' => {
            key: 'organizationName',
            limit: 30,
            question_num: 10,
            question_suffix: 'A',
            question_text: 'NAME OF ORGANIZATION TO RECEIVE INFORMATION'
          },
          'organizationAddress' => {
            key: 'organizationAddress',
            limit: 300,
            question_num: 11,
            question_suffix: 'A',
            question_text: 'ADDRESS OF ORGANIZATION TO RECEIVE INFORMATION'
          }
        },
        'organizationRepresentatives' => {
          key: "organizationRepresentatives#{ITERATOR}",
          limit: 6,
          question_num: 12,
          question_suffix: 'A',
          question_text: 'ORGANIZATION REPRESENTATIVES',
          iterator: ITERATOR
        },
        'claimInformation' => {
          'statusOfClaim' => {
            key: 'statusOfClaim',
            question_num: 13,
            question_suffix: 'A',
            question_text: 'STATUS OF CLAIM'
          },
          'currentBenefit' => {
            key: 'currentBenefit',
            question_num: 14,
            question_suffix: 'A',
            question_text: 'CURRENT BENEFIT'
          },
          'paymentHistory' => {
            key: 'paymentHistory',
            question_num: 15,
            question_suffix: 'A',
            question_text: 'PAYMENT HISTORY'
          },
          'amountOwed' => {
            key: 'amountOwed',
            question_num: 16,
            question_suffix: 'A',
            question_text: 'AMOUNT OWED'
          },
          'minor' => {
            key: 'minor',
            question_num: 17,
            question_suffix: 'A',
            question_text: 'MINOR'
          },
          'other' => {
            key: 'other',
            question_num: 18,
            question_suffix: 'A',
            question_text: 'OTHER'
          },
          'otherText' => {
            key: 'otherText',
            limit: 30,
            question_num: 19,
            question_suffix: 'A',
            question_text: 'OTHER TEXT'
          }
        },
        'isLimited' => {
          key: 'isLimited',
          question_num: 20,
          question_suffix: 'A',
          question_text: 'IS LIMITED'
        },
        'isNotLimited' => {
          key: 'isNotLimited',
          question_num: 21,
          question_suffix: 'A',
          question_text: 'IS NOT LIMITED'
        },
        'lengthOfRelease' => {
          'isOngoing' => {
            key: 'isOngoing',
            question_num: 22,
            question_suffix: 'A',
            question_text: 'IS ONGOING'
          },
          'isDated' => {
            key: 'isDated',
            question_num: 23,
            question_suffix: 'A',
            question_text: 'IS DATED'
          },
          'releaseDate' => {
            key: 'releaseDate',
            question_num: 24,
            question_suffix: 'A',
            question_text: 'RELEASE DATE'
          }
        },
        'securityQuestion' => {
          key: 'question',
          question_num: 25,
          question_suffix: 'A',
          question_text: 'SECURITY QUESTION'
        },
        'securityAnswer' => {
          key: 'answer',
          question_num: 26,
          question_suffix: 'A',
          question_text: 'SECURITY ANSWER'
        },
        'statementOfTruthSignature' => {
          key: 'statementOfTruthSignature',
          limit: 50,
          question_num: 27,
          question_suffix: 'A',
          question_text: 'STATEMENT OF TRUTH SIGNATURE'
        },
        'dateSigned' => {
          key: 'dateSigned',
          limit: 20,
          question_num: 28,
          question_suffix: 'A',
          question_text: 'DATE SIGNED'
        },
        'ssn2' => {
          key: 'ssn2',
          limit: 10,
          question_num: 29,
          question_suffix: 'A',
          question_text: 'SSN PART 2'
        },
        'ssn3' => {
          key: 'ssn3',
          limit: 10,
          question_num: 30,
          question_suffix: 'A',
          question_text: 'SSN PART 3'
        }
      }.freeze

      SECURITY_QUESTIONS = {
        'pin' => 'I would like to use a pin or password',
        'motherBornLocation' => 'The city and state your mother was born in',
        'highSchool' => 'The name of the high school you attended',
        'petName' => 'Your first pet’s name',
        'teacherName' => 'Your favorite teacher’s name',
        'fatherMiddleName' => 'Your father’s middle name'
      }.freeze

      def merge_fields(_options = {})
        @form_data = @form_data.deep_dup

        merge_claimant_personal_info
        merge_claimant_address
        merge_third_party_info
        merge_organization_info
        merge_claim_information
        merge_length_of_release
        merge_security_info

        @form_data['dateSigned'] = format_date(@form_data['dateSigned']) if @form_data['dateSigned']

        @form_data
      end

      private

      def merge_claimant_personal_info
        return unless @form_data['claimantPersonalInformation']

        person = @form_data['claimantPersonalInformation']

        if person['fullName']
          @form_data['claimantPersonalInformation']['fullName'] = combine_full_name(person['fullName'])
        end

        if person['ssn']
          ssn = person['ssn'].delete('-')
          @form_data['claimantPersonalInformation']['ssn'] = ssn
          @form_data['ssn2'] = ssn
          @form_data['ssn3'] = ssn
        end

        return unless person['dateOfBirth']

        @form_data['claimantPersonalInformation']['dateOfBirth'] = format_date(person['dateOfBirth'])
      end

      def merge_claimant_address
        return unless @form_data['claimantAddress']

        addr = @form_data['claimantAddress']
        if addr.key?('addressLine1')
          mapped_addr = {
            'street' => addr['addressLine1'],
            'street2' => addr['addressLine2'],
            'street3' => addr['addressLine3'],
            'city' => addr['city'],
            'state' => addr['stateCode'],
            'postalCode' => addr['zipCode'],
            'country' => addr['countryName'] || addr['countryCodeIso3']
          }
          @form_data['claimantAddress'] = combine_full_address_extras(mapped_addr)
        else
          @form_data['claimantAddress'] = combine_full_address_extras(addr)
        end
      end

      def merge_third_party_info
        if @form_data['thirdPartyPersonAddress']
          @form_data['thirdPartyPersonAddress'] = combine_full_address_extras(@form_data['thirdPartyPersonAddress'])
        end

        return unless @form_data['thirdPartyPersonName']

        @form_data['thirdPartyPersonName'] = combine_full_name(@form_data['thirdPartyPersonName'])
      end

      def merge_organization_info
        if @form_data['thirdPartyOrganizationInformation']&.key?('organizationAddress')
          @form_data['thirdPartyOrganizationInformation']['organizationAddress'] =
            combine_full_address_extras(@form_data['thirdPartyOrganizationInformation']['organizationAddress'])
        end

        return unless @form_data['organizationRepresentatives']

        @form_data['organizationRepresentatives'] = @form_data['organizationRepresentatives'].map do |rep|
          combine_full_name(rep['fullName'])
        end
      end

      def merge_claim_information
        return unless @form_data['claimInformation']

        info = @form_data['claimInformation']
        has_any = false

        %w[statusOfClaim currentBenefit paymentHistory amountOwed minor other].each do |field|
          if info[field]
            info[field] = 'X'
            has_any = true
          else
            info[field] = nil
          end
        end

        if has_any
          @form_data['isLimited'] = 'X'
          @form_data['isNotLimited'] = nil
        else
          @form_data['isLimited'] = nil
          @form_data['isNotLimited'] = 'X'
        end
      end

      def merge_length_of_release
        return unless @form_data['lengthOfRelease']

        release = @form_data['lengthOfRelease']
        if release['lengthOfRelease'] == 'ongoing'
          @form_data['lengthOfRelease']['isOngoing'] = 'X'
          @form_data['lengthOfRelease']['isDated'] = nil
          @form_data['lengthOfRelease']['releaseDate'] = nil
        elsif release['lengthOfRelease'] == 'date'
          @form_data['lengthOfRelease']['isOngoing'] = nil
          @form_data['lengthOfRelease']['isDated'] = 'X'
          @form_data['lengthOfRelease']['releaseDate'] = format_date(release['date'])
        end
      end

      def merge_security_info
        merge_security_question
        merge_security_answer
      end

      def merge_security_question
        return unless @form_data['securityQuestion']

        q_key = @form_data['securityQuestion']['question']
        if q_key == 'create'
          if @form_data['securityAnswer'] && @form_data['securityAnswer']['securityAnswerCreate']
            @form_data['securityQuestion']['question'] =
              @form_data['securityAnswer']['securityAnswerCreate']['question']
          end
        else
          @form_data['securityQuestion']['question'] = SECURITY_QUESTIONS[q_key]
        end
      end

      def merge_security_answer
        return unless @form_data['securityAnswer']

        ans = @form_data['securityAnswer']
        if ans['securityAnswerText']
          @form_data['securityAnswer']['answer'] = ans['securityAnswerText']
        elsif ans['securityAnswerLocation']
          loc = ans['securityAnswerLocation']
          @form_data['securityAnswer']['answer'] = "#{loc['city']}, #{loc['state']}"
        elsif ans['securityAnswerCreate']
          @form_data['securityAnswer']['answer'] = ans['securityAnswerCreate']['answer']
        end
      end

      def format_date(date_str)
        return nil if date_str.blank?

        Date.parse(date_str).strftime('%m/%d/%Y')
      rescue ArgumentError
        date_str
      end
    end
  end
end
