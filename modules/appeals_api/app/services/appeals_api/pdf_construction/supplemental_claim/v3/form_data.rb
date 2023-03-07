# frozen_string_literal: true

require 'appeals_api/sc_evidence'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V3
        class FormData
          BENEFIT_TYPE_CODES = {
            'compensation' => 1,
            'pensionSurvivorsBenefits' => 2,
            'fiduciary' => 3,
            'lifeInsurance' => 4,
            'education' => 5,
            'veteranReadinessAndEmployment' => 6,
            'loanGuaranty' => 7,
            'veteransHealthAdministration' => 8,
            'nationalCemeteryAdministration' => 9
          }.freeze

          CLAIMANT_TYPE_CODES = {
            'veteran' => 1,
            'spouse_of_veteran' => 2,
            'child_of_veteran' => 3,
            'parent_of_veteran' => 4,
            'other' => 5
          }.freeze

          LONG_SIGNATURE_THRESHOLD = 70
          LONG_EMAIL_THRESHOLD = 120
          MAX_SIGNATURE_LENGTH = 180

          def initialize(supplemental_claim)
            @supplemental_claim = supplemental_claim
          end

          delegate :veteran_dob_month, :veteran_dob_day, :veteran_dob_year, :signing_appellant_zip_code,
                   :date_signed, :signing_appellant, :appellant_local_time, :contestable_issues,
                   :new_evidence_locations, :claimant_type_other_text, :new_evidence_dates, :claimant, :veteran,
                   :alternate_signer_full_name,
                   to: :supplemental_claim

          delegate :first_name, :last_name, :middle_initial, :file_number, :service_number,
                   :insurance_policy_number,
                   to: :veteran, prefix: true

          delegate :first_name, :last_name, :middle_initial,
                   to: :claimant, prefix: true

          delegate :email, :number_and_street, :city, :state_code, :country_code,
                   to: :signing_appellant, prefix: true

          def benefit_type_code
            BENEFIT_TYPE_CODES[supplemental_claim.benefit_type]
          end

          def claimant_type_code
            CLAIMANT_TYPE_CODES[supplemental_claim.claimant_type]
          end

          def form_5103_notice_acknowledged
            return nil unless supplemental_claim.benefit_type == 'compensation'

            supplemental_claim.form_5103_notice_acknowledged ? 1 : 'Off' # 1 => 'YES' OFF => 'NO'
          end

          def new_evidence_locations
            evidence_records.map(&:location)
          end

          def new_evidence_dates
            evidence_records.map(&:dates)
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

          def long_email?
            signing_appellant_email.length > LONG_EMAIL_THRESHOLD
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

          def alternate_signer_signature
            if alternate_signer?
              if alternate_signer_full_name.length > LONG_SIGNATURE_THRESHOLD
                return 'See attached page for signature of alternate signer'
              end

              signature
            end
          end

          def alternate_signer_date_signed
            date_signed if alternate_signer?
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
