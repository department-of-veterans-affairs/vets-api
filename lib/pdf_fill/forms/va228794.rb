# frozen_string_literal: true

module PdfFill
  module Forms
    class Va228794 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'facilityCode' => {
            key: 'institution_facility_code'
          }
        },
        'institutionNameAndAddress' => {
          key: 'institution_address'
        },
        'primaryOfficialDetails' => {
          'fullName' => {
            key: 'primary_certifying_official_name'
          },
          'title' => {
            key: 'primary_certifying_official_title'
          },
          'phoneNumber' => {
            key: 'primary_certifying_official_phone'
          },
          'emailAddress' => {
            key: 'primary_certifying_official_email'
          },
          'signature' => {
            key: 'primary_certifying_official_signature'
          },
          'receivesBenefits' => {
            key: 'primary_certifying_official_receives_benefits'
          }
        },
        'primaryOfficialTraining' => {
          'trainingCompletionDate' => {
            key: 'primary_certifying_official_section305_date'
          }
        },
        'additionalCertifyingOfficials' => {
          limit: 7,
          label_all: true,
          'fullName' => {
            key: "additional_certifying_officials_#{ITERATOR}_name"
          },
          'title' => {
            key: "additional_certifying_officials_#{ITERATOR}_title"
          },
          'phoneNumber' => {
            key: "additional_certifying_officials_#{ITERATOR}_phone"
          },
          'emailAddress' => {
            key: "additional_certifying_officials_#{ITERATOR}_email"
          },
          'trainingCompletionDate' => {
            key: "additional_certifying_officials_#{ITERATOR}_section305_date"
          },
          'signature' => {
            key: "additional_certifying_officials_#{ITERATOR}_signature"
          },
          'receivesBenefits' => {
            key: "additional_certifying_officials_#{ITERATOR}_receives_benefits"
          }
        },
        'readOnlyCertifyingOfficial' => {
          limit: 4,
          label_all: true,
          'name' => {
            key: "read_only_scos_#{ITERATOR}_name"
          }
        },
        'remarks' => {
          key: 'remarks'
        },
        'statementOfTruthSignature' => {
          key: 'designating_official_signature'
        },
        'dateSigned' => {
          key: 'signature_date'
        },
        'designatingOfficial' => {
          'emailAddress' => {
            key: 'signature_email'
          },
          'signatureName' => {
            key: 'signature_name'
          },
          'phoneNumber' => {
            key: 'signature_phone'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        form_data['designatingOfficial']['signatureName'] =
          combine_full_name(form_data['designatingOfficial']['fullName']) +
          ", #{form_data['designatingOfficial']['title']}"
        form_data['designatingOfficial']['phoneNumber'] = combine_phone_numbers(form_data['designatingOfficial'])
        form_data['institutionNameAndAddress'] = <<~TEXT
          #{form_data.dig('institutionDetails', 'institutionName')}
          #{combine_full_address(form_data.dig('institutionDetails', 'institutionAddress')) || ''}
        TEXT

        form_data['institutionDetails']['facilityCode'] = '' unless form_data['institutionDetails']['hasVaFacilityCode']

        format_primary_official(form_data)
        format_additional_officials(form_data)
        format_read_only_officials(form_data)

        form_data
      end

      def format_primary_official(form_data)
        form_data['primaryOfficialDetails']['fullName'] =
          combine_full_name(form_data['primaryOfficialDetails']['fullName'])
        form_data['primaryOfficialDetails']['phoneNumber'] = combine_phone_numbers(form_data['primaryOfficialDetails'])
        form_data['primaryOfficialDetails']['signature'] = 'Online submission - no signature required'
        form_data['primaryOfficialDetails']['receivesBenefits'] =
          form_data.dig('primaryOfficialBenefitStatus', 'hasVaEducationBenefits') ? 'Yes' : 'No'

        if form_data['primaryOfficialTraining']['trainingExempt']
          form_data['primaryOfficialTraining']['trainingCompletionDate'] = 'EXEMPT'
        end
      end

      def format_additional_officials(form_data)
        (form_data['additionalCertifyingOfficials'] || []).each do |data|
          details = data['additionalCertifyingOfficialsDetails']
          data['fullName'] = combine_full_name(details['fullName'])
          data['signature'] = 'Online submission - no signature required'
          data['receivesBenefits'] = details['hasVaEducationBenefits'] ? 'Yes' : 'No'
          data['title'] = details['title']
          data['phoneNumber'] = combine_phone_numbers(details)
          data['emailAddress'] = details['emailAddress']
          data['trainingCompletionDate'] = details['trainingExempt'] ? 'EXEMPT' : details['trainingCompletionDate']
        end
      end

      def format_read_only_officials(form_data)
        (form_data['readOnlyCertifyingOfficial'] || []).each do |data|
          data['name'] = combine_full_name(data['fullName'])
        end
      end

      def combine_phone_numbers(data)
        data['internationalPhoneNumber'].presence || data['phoneNumber']
      end
    end
  end
end
