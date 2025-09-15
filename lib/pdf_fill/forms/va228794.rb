# frozen_string_literal: true

module PdfFill
  module Forms
    class Va228794 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      KEY = {
        'institutionDetails' => {
          'facilityCode' => {
            key: 'institution[facility_code]'
          }
        },
        'institutionNameAndAddress' => {
          key: 'institution[address]'
        },
        'primaryOfficialDetails' => {
          'fullName' => {
            key: 'primary_certifying_official[name]'
          },
          'title' => {
            key: 'primary_certifying_official[title]'
          },
          'phoneNumber' => {
            key: 'primary_certifying_official[phone]'
          },
          'emailAddress' => {
            key: 'primary_certifying_official[email]'
          },
          'signature' => {
            key: 'primary_certifying_official[signature]'
          },
          'receivesBenefits' => {
            key: 'primary_certifying_official[receives_benefits]'
          }
        },
        'primaryOfficialTraining' => {
          'trainingCompletionDate' => {
            key: 'primary_certifying_official[section305_date]'
          }
        },
        'additionalCertifyingOfficials' => {
          limit: 7,
          label_all: true,
          'fullName' => {
            key: "additional_certifying_officials[#{ITERATOR}][name]"
          },
          'title' => {
            key: "additional_certifying_officials[#{ITERATOR}][title]"
          },
          'phoneNumber' => {
            key: "additional_certifying_officials[#{ITERATOR}][phone]"
          },
          'emailAddress' => {
            key: "additional_certifying_officials[#{ITERATOR}][email]"
          },
          'trainingCompletionDate' => {
            key: "additional_certifying_officials[#{ITERATOR}][section305_date]"
          },
          'signature' => {
            key: "additional_certifying_officials[#{ITERATOR}][signature]"
          },
          'receivesBenefits' => {
            key: "additional_certifying_officials[#{ITERATOR}][receives_benefits]"
          }
        },
        'readOnlyCertifyingOfficial' => {
          limit: 4,
          label_all: true,
          'name' => {
            key: "read_only_scos[#{ITERATOR}][name]"
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
            key: 'signature_print_name'
          },
          'phoneNumber' => {
            key: 'signature_phone'
          }
        }
      }.freeze

      def merge_fields(_options = {})
        form_data = JSON.parse(JSON.generate(@form_data))

        form_data['designatingOfficial']['signatureName'] =
          combine_full_name(@form_data['designatingOfficial']['fullName'])
        form_data['institutionNameAndAddress'] = <<~TEXT
          #{form_data.dig('institutionDetails', 'institutionName')}
          #{combine_full_address(form_data.dig('institutionDetails', 'institutionAddress')) || ''}
        TEXT

        format_primary_official(form_data)
        format_additional_officials(form_data)
        format_read_only_officials(form_data)

        form_data
      end

      def format_primary_official(form_data)
        form_data['primaryOfficialDetails']['fullName'] =
          combine_full_name(form_data['primaryOfficialDetails']['fullName'])
        form_data['primaryOfficialDetails']['signature'] = form_data['primaryOfficialDetails']['fullName']
        form_data['primaryOfficialDetails']['receivesBenefits'] =
          form_data.dig('primaryOfficialBenefitStatus', 'hasVaEducationBenefits') ? 'Yes' : 'No'
      end

      def format_additional_officials(form_data)
        (form_data['additionalCertifyingOfficials'] || []).each do |data|
          details = data['additionalCertifyingOfficialsDetails']
          full_name = combine_full_name(details['fullName'])
          data['fullName'] = full_name
          data['signature'] = full_name
          data['receivesBenefits'] = details['hasVaEducationBenefits'] ? 'Yes' : 'No'
          data['title'] = details['title']
          data['phoneNumber'] = details['phoneNumber']
          data['emailAddress'] = details['emailAddress']
          data['trainingCompletionDate'] = details['trainingCompletionDate']
        end
      end

      def format_read_only_officials(form_data)
        (form_data['readOnlyCertifyingOfficial'] || []).each do |data|
          data['name'] = combine_full_name(data['fullName'])
        end
      end
    end
  end
end
