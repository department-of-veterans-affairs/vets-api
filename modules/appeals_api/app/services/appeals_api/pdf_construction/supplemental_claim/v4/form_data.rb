# frozen_string_literal: true

require 'appeals_api/sc_evidence'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V4
        class FormData
          BENEFIT_TYPE_CODES = {

            'education' => 1,
            'veteranReadinessAndEmployment' => 2,
            'pensionSurvivorsBenefits' => 3,
            'compensation' => 4,
            'loanGuaranty' => 8,
            'nationalCemeteryAdministration' => 9,
            'fiduciary' => 10,
            'lifeInsurance' => 11,
            'veteransHealthAdministration' => 12
          }.freeze

          CLAIMANT_TYPE_CODES = {
            'spouse_of_veteran' => 1,
            'child_of_veteran' => 2,
            'other' => 3,
            'parent_of_veteran' => 4,
            'fiduciary' => 5
          }.freeze

          LONG_SIGNATURE_THRESHOLD = 70
          LONG_EMAIL_THRESHOLD = 120
          MAX_SIGNATURE_LENGTH = 180

          def initialize(supplemental_claim)
            @supplemental_claim = supplemental_claim
          end

          delegate :veteran_dob_month, :veteran_dob_day, :veteran_dob_year, :signing_appellant_zip_code,
                   :date_signed, :signing_appellant, :appellant_local_time, :contestable_issues,
                   :new_evidence_locations, :new_evidence_dates, :claimant, :veteran,
                   :alternate_signer_full_name,
                   to: :supplemental_claim

          delegate :first_name, :last_name, :middle_initial, :file_number, :service_number, :email,
                   :number_and_street, :city, :zip_code, :state_code, :country_code, :insurance_policy_number,
                   to: :veteran, prefix: true

          delegate :first_name, :last_name, :middle_initial, :email, :number_and_street, :city, :zip_code,
                   :state_code, :country_code, to: :claimant, prefix: true

          delegate :email, :number_and_street, :city, :state_code, :country_code,
                   to: :signing_appellant, prefix: true

          def benefit_type_code
            BENEFIT_TYPE_CODES[supplemental_claim.benefit_type]
          end

          def claimant_type_code
            CLAIMANT_TYPE_CODES[supplemental_claim.claimant_type]
          end

          def claimant_type_other_text
            supplemental_claim.claimant_type == 'other' ? supplemental_claim.claimant_type_other_text : nil
          end

          def form_5103_notice_acknowledged
            return nil unless supplemental_claim.benefit_type == 'compensation'

            supplemental_claim.form_5103_notice_acknowledged ? 1 : 2
          end

          def new_evidence_locations
            evidence_records.map(&:location)
          end

          def new_evidence_dates
            evidence_records.map(&:dates_month_format)
          end

          def veteran_ssn_first_three
            veteran.ssn[0..2]
          end

          def veteran_ssn_middle_two
            veteran.ssn[3..4]
          end

          def veteran_ssn_last_four
            veteran.ssn[5..8]
          end

          def signing_appellant_zip_code
            if signing_appellant.zip_code_5 == '00000'
              signing_appellant.international_postal_code || '00000'
            else
              signing_appellant.zip_code_5
            end
          end

          def veteran_zip_code
            if veteran.zip_code_5 == '00000'
              veteran.international_postal_code || '00000'
            else
              veteran.zip_code_5
            end
          end

          def veteran_international_phone
            veteran.phone_formatted.to_s unless veteran_domestic_phone?
          end

          def veteran_domestic_phone?
            # The form has no field for an extension on a domestic number, so if a domestic number has
            # an extension, we put it in the international field instead.
            veteran.domestic_phone? && veteran.phone_data['phoneNumberExt'].blank?
          end

          def veteran_phone_area_code
            veteran.phone_data['areaCode'] if veteran_domestic_phone?
          end

          def veteran_phone_prefix
            veteran.phone_data['phoneNumber'][0..2] if veteran_domestic_phone?
          end

          def veteran_phone_line_number
            veteran.phone_data['phoneNumber'][3..] if veteran_domestic_phone?
          end

          def claimant_domestic_phone?
            # The form has no field for an extension on a domestic number, so if a domestic number has
            # an extension, we put it in the international field instead.
            claimant.domestic_phone? && claimant.phone_data && claimant.phone_data['phoneNumberExt'].blank?
          end

          def claimant_international_phone
            claimant.phone_formatted.to_s unless claimant_domestic_phone?
          end

          def claimant_phone_area_code
            claimant.phone_data['areaCode'] if claimant_domestic_phone?
          end

          def claimant_phone_prefix
            claimant.phone_data['phoneNumber'][0..2] if claimant_domestic_phone?
          end

          def claimant_phone_line_number
            claimant.phone_data['phoneNumber'][3..] if claimant_domestic_phone?
          end

          def ci_decision_date_month(index)
            contestable_issues.at(index)&.decision_date_string&.split('-')&.at(1)
          end

          def ci_decision_date_day(index)
            contestable_issues.at(index)&.decision_date_string&.split('-')&.at(2)
          end

          def ci_decision_date_year(index)
            contestable_issues.at(index)&.decision_date_string&.split('-')&.at(0)
          end

          9.times do |i|
            define_method(:"ci_decision_date_#{i}_month") do
              ci_decision_date_month(i)
            end

            define_method(:"ci_decision_date_#{i}_day") do
              ci_decision_date_day(i)
            end

            define_method(:"ci_decision_date_#{i}_year") do
              ci_decision_date_year(i)
            end
          end

          def domestic_phone?
            # The form has no field for an extension on a domestic number, so if a domestic number has
            # an extension, we put it in the international field instead.
            signing_appellant.domestic_phone? && signing_appellant.phone_data['phoneNumberExt'].blank?
          end

          def phone_area_code
            signing_appellant.phone_data['areaCode'] if domestic_phone?
          end

          def phone_prefix
            signing_appellant.phone_data['phoneNumber'][0..2] if domestic_phone?
          end

          def phone_line_number
            signing_appellant.phone_data['phoneNumber'][3..] if domestic_phone?
          end

          def international_phone
            signing_appellant.phone_formatted.to_s unless domestic_phone?
          end

          def veteran_long_email?
            veteran_email.length > LONG_EMAIL_THRESHOLD
          end

          def veteran_claimant_rep_signature
            unless alternate_signer?
              if signing_appellant.full_name.length > LONG_SIGNATURE_THRESHOLD
                return 'See attached page for signature of veteran claimant or rep'
              end

              signature
            end
          end

          def veteran_claimant_rep_date_signed
            date_signed unless alternate_signer?
          end

          def veteran_claimant_rep_date_signed_month
            date_signed.split('/')[0] unless alternate_signer?
          end

          def veteran_claimant_rep_date_signed_day
            date_signed.split('/')[1] unless alternate_signer?
          end

          def veteran_claimant_rep_date_signed_year
            date_signed.split('/')[2] unless alternate_signer?
          end

          def alternate_signer_signature
            if alternate_signer?
              if alternate_signer_full_name.length > LONG_SIGNATURE_THRESHOLD
                return 'See attached page for signature of alternate signer'
              end

              signature
            end
          end

          def alternate_signer_month_signed
            supplemental_claim.appellant_local_time.strftime('%m') if alternate_signer?
          end

          def alternate_signer_day_signed
            supplemental_claim.appellant_local_time.strftime('%d') if alternate_signer?
          end

          def alternate_signer_year_signed
            supplemental_claim.appellant_local_time.strftime('%Y') if alternate_signer?
          end

          def alternate_signer?
            alternate_signer_full_name.present?
          end

          def long_signature?
            full_name_for_signature.length > LONG_SIGNATURE_THRESHOLD
          end

          def signature
            "#{full_name_for_signature[0...MAX_SIGNATURE_LENGTH]} - Signed by digital authentication to api.va.gov"
          end

          private

          attr_accessor :supplemental_claim

          def full_name_for_signature
            alternate_signer? ? alternate_signer_full_name : signing_appellant.full_name
          end

          def evidence_records
            return @evidence_records if @evidence_records

            @evidence_records = supplemental_claim.new_evidence
            if supplemental_claim.evidence_submission_indicated?
              @evidence_records.append(
                AppealsApi::ScEvidence.new(
                  :upload,
                  {
                    'locationAndName' => 'Veteran indicated they will send evidence documents to VA.',
                    'evidenceDates' => nil
                  }
                )
              )
            end
            @evidence_records
          end
        end
      end
    end
  end
end
