# frozen_string_literal: true

require 'appeals_api/sc_evidence'

module AppealsApi
  module PdfConstruction
    module SupplementalClaim
      module V2
        class FormData
          UPLOAD_INDICATED = 'Veteran indicated they will send evidence documents to VA.'

          def initialize(supplemental_claim)
            @supplemental_claim = supplemental_claim
          end

          delegate :veteran_dob_month, :veteran_dob_day, :veteran_dob_year,
                   :insurance_policy_number, :date_signed, :signing_appellant, :appellant_local_time,
                   :contestable_issues, :soc_opt_in, :claimant_type_other_text,
                   :claimant, :veteran, :alternate_signer_full_name,
                   to: :supplemental_claim

          delegate :first_name, :last_name,
                   to: :veteran, prefix: true

          delegate :first_name, :last_name,
                   to: :claimant, prefix: true

          delegate :number_and_street, :city, :email,
                   to: :signing_appellant, prefix: true

          def benefit_type
            benefit_type_form_codes[supplemental_claim.benefit_type]
          end

          def claimant_type
            claimant_type_form_codes[supplemental_claim.claimant_type]
          end

          def soc_ssoc_opt_in
            soc_opt_in ? 1 : 'Off'
          end

          def soc_date_text(issue)
            date = issue.soc_date_formatted

            return '' unless date

            "SOC/SSOC Date: #{date}"
          end

          def form_5103_notice_acknowledged
            return nil unless supplemental_claim.benefit_type == 'compensation'

            supplemental_claim.form_5103_notice_acknowledged ? 1 : 'Off' # 1 => 'YES' OFF => 'NO'
          end

          def signature_of_veteran_claimant_or_rep
            return 'See attached page for signature of veteran claimant or rep' if long_signature?

            "#{signing_appellant.full_name[0...180]} - Signed by digital authentication to api.va.gov"
          end

          def signature_of_alternate_signer
            return 'See attached page for signature of alternate signer' if long_signature?

            "#{alternate_signer_full_name[0...180]} - Signed by digital authentication to api.va.gov"
          end

          def long_signature?
            if alternate_signer_full_name.present?
              alternate_signer_full_name.length > 70
            else
              signing_appellant.full_name.length > 70
            end
          end

          def print_name_veteran_claimaint_or_rep
            signing_appellant.full_name[0...180]
          end

          def new_evidence_locations
            evidence_records.map(&:location)
          end

          def new_evidence_dates
            evidence_records.map(&:dates_day_format)
          end

          def veteran_ssn_first_three
            # form only calls for veteran ssn data
            veteran.ssn[0..2]
          end

          def veteran_ssn_middle_two
            # form only calls for veteran ssn data
            veteran.ssn[3..4]
          end

          def veteran_ssn_last_four
            # form only calls for veteran ssn data
            veteran.ssn[5..8]
          end

          def signing_appellant_phone
            signing_appellant.phone_formatted.to_s
          end

          def signing_appellant_state
            signing_appellant.state_code
          end

          def signing_appellant_zip_code
            if signing_appellant.zip_code_5 == '00000'
              signing_appellant.international_postal_code || '00000'
            else
              signing_appellant.zip_code_5
            end
          end

          def long_appellant_email?
            signing_appellant.email.length > 120
          end

          private

          attr_accessor :supplemental_claim

          def evidence_records
            return @evidence_records if @evidence_records

            @evidence_records = supplemental_claim.new_evidence
            if evidence_submission_indicated?
              upload = AppealsApi::ScEvidence.new(:upload,
                                                  { 'locationAndName' => UPLOAD_INDICATED,
                                                    'evidenceDates' => nil })
              @evidence_records.append(upload)
            end
            @evidence_records
          end

          def evidence_submission_indicated?
            supplemental_claim.evidence_submission_indicated?
          end

          def benefit_type_form_codes
            {
              'compensation' => 1,
              'pensionSurvivorsBenefits' => 2,
              'fiduciary' => 3,
              'lifeInsurance' => 4,
              'education' => 5,
              'veteranReadinessAndEmployment' => 6,
              'loanGuaranty' => 7,
              'veteransHealthAdministration' => 8,
              'nationalCemeteryAdministration' => 9
            }
          end

          def claimant_type_form_codes
            {
              'veteran' => 1,
              'spouse_of_veteran' => 2,
              'child_of_veteran' => 3,
              'parent_of_veteran' => 4,
              'other' => 5
            }
          end
        end
      end
    end
  end
end
