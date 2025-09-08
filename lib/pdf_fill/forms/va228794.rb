# frozen_string_literal: true

module PdfFill
  module Forms
    class Va228794 < FormBase
      include FormHelper

      ITERATOR = PdfFill::HashConverter::ITERATOR

      ADDITIONAL_OFFICIAL_FIELDS_GEN = lambda { |i|
        {
          'fullName' => {
            key: "additional_certifying_officials[#{i}][name]"
          },
          'title' => {
            key: "additional_certifying_officials[#{i}][title]"
          },
          'phoneNumber' => {
            key: "additional_certifying_officials[#{i}][phone]"
          },
          'emailAddress' => {
            key: "additional_certifying_officials[#{i}][email]"
          },
          'trainingCompletionDate' => {
            key: "additional_certifying_officials[#{i}][section305_date]"
          },
          'signature' => {
            key: "additional_certifying_officials[#{i}][signature]"
          },
          'receivesBenefits' => {
            key: "additional_certifying_officials[#{i}][receives_benefits]"
          }
        }
      }

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
        'additionalCertifyingOfficials_0' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(0),
        'additionalCertifyingOfficials_1' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(1),
        'additionalCertifyingOfficials_2' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(2),
        'additionalCertifyingOfficials_3' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(3),
        'additionalCertifyingOfficials_4' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(4),
        'additionalCertifyingOfficials_5' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(5),
        'additionalCertifyingOfficials_6' => ADDITIONAL_OFFICIAL_FIELDS_GEN.call(6),
        'readOnlyCertifyingOfficial_0' => {
          key: 'read_only_scos[0][name]'
        },
        'readOnlyCertifyingOfficial_1' => {
          key: 'read_only_scos[1][name]'
        },
        'readOnlyCertifyingOfficial_2' => {
          key: 'read_only_scos[2][name]'
        },
        'readOnlyCertifyingOfficial_3' => {
          key: 'read_only_scos[3][name]'
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
        @form_data['designatingOfficial']['signatureName'] =
          combine_full_name(@form_data['designatingOfficial']['fullName'])
        @form_data['institutionNameAndAddress'] = <<~TEXT
          #{@form_data.dig('institutionDetails', 'institutionName')}
          #{combine_full_address(@form_data.dig('institutionDetails', 'institutionAddress')) || ''}
        TEXT

        format_primary_official
        format_additional_officials
        format_read_only_officials

        @form_data
      end

      def format_primary_official
        @form_data['primaryOfficialDetails']['fullName'] =
          combine_full_name(@form_data['primaryOfficialDetails']['fullName'])
        @form_data['primaryOfficialDetails']['signature'] = @form_data['primaryOfficialDetails']['fullName']
        @form_data['primaryOfficialDetails']['receivesBenefits'] =
          @form_data.dig('primaryOfficialBenefitStatus', 'hasVaEducationBenefits') ? 'Yes' : 'No'
      end

      def format_additional_officials
        (@form_data['additionalCertifyingOfficials'] || []).each_with_index do |data, i|
          details = data['additionalCertifyingOfficialsDetails']
          full_name = combine_full_name(details['fullName'])
          @form_data["additionalCertifyingOfficials_#{i}"] =
            {
              'fullName' => full_name,
              'title' => details['title'],
              'phoneNumber' => details['phoneNumber'],
              'emailAddress' => details['emailAddress'],
              'trainingCompletionDate' => details['trainingCompletionDate'],
              'signature' => full_name,
              'receivesBenefits' => details['hasVaEducationBenefits'] ? 'Yes' : 'No'
            }
        end
      end

      def format_read_only_officials
        (@form_data['readOnlyCertifyingOfficial'] || []).each_with_index do |data, i|
          @form_data["readOnlyCertifyingOfficial_#{i}"] = combine_full_name(data['fullName'])
        end
      end
    end
  end
end
