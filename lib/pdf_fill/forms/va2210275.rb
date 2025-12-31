# frozen_string_literal: true

module PdfFill
  module Forms
    class Va2210275 < FormBase
      include FormHelper
      include FormHelper::PhoneNumberFormatting

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'mainInstitution' => {
          'institutionName' => {
            key: 'institutionName',
            question_text: 'NAME OF EDUCATIONAL TRAINING INSTITUTION (ETI)',
            question_num: 1,
            limit: 120
          },
          'facilityCode' => {
            key: 'facilityCode',
            question_text: 'FACILITY CODE',
            question_num: 2,
            limit: 8
          },
          'mailingAddress' => {
            key: 'mailingAddress',
            limit: 245,
            question_text: 'MAILING ADDRESS OF EDUCATIONAL TRAINING INSTITUTION',
            question_num: 3
          }
        },
        'agreementType' => {
          question_text: 'AGREEMENT_TYPE (CHECK ONE)',
          question_num: 4,
          'newCommitment' => {
            key: 'newCommitment',
            question_text: 'NEW COMMITMENT',
            question_num: 4,
            question_suffix: 'A'
          },
          'withdrawal' => {
            key: 'withdrawal',
            question_text: 'WITHDRAWAL',
            question_num: 4,
            question_suffix: 'B'
          }
        },
        'additionalInstitutions' => {
          question_num: 5,
          question_text: 'List all participating locations',
          first_key: 'institutionName',
          limit: 6,
          label_all: true,
          'institutionName' => {
            key: "schoolName[#{ITERATOR}]",
            limit: 55,
            question_suffix: 'A',
            question_num: 5,
            question_text: 'SCHOOL NAME'
          },
          'institutionAddress' => {
            key: "schoolLocation[#{ITERATOR}]",
            limit: 65,
            question_suffix: 'B',
            question_num: 5,
            question_text: 'SCHOOL LOCATION'
          },
          'facilityCode' => {
            key: "schoolFacilityCode[#{ITERATOR}]",
            limit: 8,
            question_suffix: 'C',
            question_num: 5,
            question_text: 'FACILITY CODE'
          },
          'fullName' => {
            key: "schoolPoc[#{ITERATOR}]",
            limit: 80,
            question_suffix: 'D',
            question_num: 5,
            question_text: 'POINT OF CONTACT'
          },
          'email' => {
            key: "schoolEmail[#{ITERATOR}]",
            limit: 80,
            question_suffix: 'E',
            question_num: 5,
            question_text: 'EMAIL ADDRESS'
          }
        },
        'newCommitment' => {
          'principlesOfExcellencePointOfContact' => {
            'fullName' => {
              key: 'pocFullName',
              question_text: 'Principles of Excellence Point of Contact, NAME (First, middle, last)',
              question_num: 6,
              limit: 40
            },
            'phone' => {
              key: 'pocPhone',
              question_text: 'Principles of Excellence Point of Contact, TELEPHONE NO. (Include Area Code)',
              question_num: 7,
              limit: 25
            },
            'email' => {
              key: 'pocEmail',
              question_text: 'Principles of Excellence Point of Contact, EMAIL',
              question_num: 8,
              limit: 40
            }
          },
          'schoolCertifyingOfficial' => {
            'fullName' => {
              key: 'scoFullName',
              question_text: 'School Certifying Official, NAME (First, middle, last)',
              question_num: 9,
              limit: 40
            },
            'phone' => {
              key: 'scoPhone',
              question_text: 'School Certifying Official, TELEPHONE NO. (Include Area Code)',
              question_num: 10,
              limit: 25
            },
            'email' => {
              key: 'scoEmail',
              question_text: 'School Certifying Official, EMAIL',
              question_num: 11,
              limit: 40
            }
          }
        },
        'statementOfTruthSignature' => {
          key: 'authSignature',
          question_text: 'SIGNATURE OF AUTHORIZING OFFICIAL',
          question_num: 12,
          limit: 80
        },
        'authorizedOfficial' => {
          'fullName' => {
            key: 'authFullName',
            question_text: 'PRINT NAME OF AUTHORIZING OFFICIAL',
            question_num: 13,
            limit: 35
          },
          'title' => {
            key: 'authTitle',
            question_text: 'TITLE OF AUTHORIZING OFFICIAL',
            question_num: 14,
            limit: 140
          },
          'phone' => {
            key: 'authPhone',
            question_text: 'TELEPHONE NUMBER',
            question_num: 15,
            limit: 18
          }
        },
        'dateSigned' => {
          key: 'authDate',
          format: 'date',
          question_text: 'DATE SIGNED (MM/DD/YYYY)',
          question_num: 16,
          limit: 15
        }
      }.freeze

      def merge_fields(_options = {})
        merge_address_helpers
        merge_agreement_type_helpers
        merge_additional_institution_helpers
        merge_point_of_contact_helpers
        merge_authorization_helpers

        @form_data
      end

      private

      def merge_address_helpers
        address = @form_data['mainInstitution'].delete('institutionAddress')
        normalize_mailing_address(address)
        @form_data['mainInstitution']['mailingAddress'] = combine_full_address_extras(address)
      end

      def merge_agreement_type_helpers
        form_value = @form_data.delete('agreementType')
        @form_data['agreementType'] = {}
        %w[newCommitment withdrawal].each do |agreement_type|
          # Set checkbox to checked or unchecked
          checked_value = form_value == agreement_type ? 'Yes' : 'Off'
          @form_data['agreementType'][agreement_type] = checked_value
        end
      end

      def merge_additional_institution_helpers
        @form_data['additionalInstitutions'].each do |institution|
          address = institution['institutionAddress']
          normalize_mailing_address(address)
          institution['institutionAddress'] = combine_full_address(address)

          # flatten nested contact info
          poc = institution.delete('pointOfContact')
          institution.merge!(poc)
          format_contact(institution)
        end
      end

      def format_contact(contact)
        contact['fullName'] = combine_full_name(contact['fullName'])
        phone = contact.delete('usPhone')&.then(&method(:format_us_phone)) ||
                contact.delete('internationalPhone')
        contact['phone'] = phone if phone.present?
      end

      def format_us_phone(number)
        expand_phone_number(number).values.join('-')
      end

      def merge_point_of_contact_helpers
        contacts = @form_data['newCommitment']
        contacts.each_value(&method(:format_contact))
      end

      def merge_authorization_helpers
        authorized_official = @form_data['authorizedOfficial']
        format_contact(authorized_official)
      end
    end
  end
end
