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

          delegate :insurance_policy_number, :date_signed, :signing_appellant, :appellant_local_time,
                   :contestable_issues, :soc_opt_in, :new_evidence_locations, :new_evidence_dates,
                   :veteran_homeless?, :preferred_email, :preferred_phone,
                   :preferred_number_and_street, :preferred_city, :preferred_state,
                   :preferred_zip_code, :preferred_country,
                   :claimant, :veteran,
                   to: :supplemental_claim

          delegate :first_name, :last_name, :middle_initial, :full_name, :file_number, :service_number,
                   to: :veteran, prefix: true

          delegate :first_name, :last_name, :middle_initial, :full_name, :claimant_type,
                   to: :claimant, prefix: true

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

          def long_signature?
            signing_appellant.full_name.length > 70
          end

          def print_name_veteran_claimaint_or_rep
            signing_appellant.full_name[0...180]
          end

          def date_signed_mm
            appellant_local_time.strftime '%m'
          end

          def date_signed_dd
            appellant_local_time.strftime '%d'
          end

          def date_signed_yyyy
            appellant_local_time.strftime '%Y'
          end

          def new_evidence_locations
            evidence_records.map(&:location)
          end

          def new_evidence_dates
            evidence_records.map(&:dates)
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

          def preferred_phone
            signing_appellant.phone_formatted.to_s
          end

          def preferred_mailing_address
            [
              signing_appellant.number_and_street,
              signing_appellant.city,
              signing_appellant.state_code,
              signing_appellant.zip_code,
              signing_appellant.country_code
            ].compact.join(', ')
          end

          def preferred_number_and_street
            signing_appellant.number_and_street
          end

          def preferred_city
            signing_appellant.city
          end

          def preferred_state
            signing_appellant.state_code
          end

          def preferred_zip_code_5
            # Limiting to 5 characters to fix some flaky tests.
            # TODO: Figure out a better handling for international postal codes (IPC) for this PDF.
            #      Currently, Appellant#zip_code returns the IPC in some circumstances, which is probably innacurate
            #      if we truncate it to 5 characters.
            signing_appellant.zip_code&.first(5)
          end

          def preferred_country
            signing_appellant.country_code
          end

          def preferred_email
            return 'See attached page for preferred email' if long_preferred_email?

            signing_appellant.email
          end

          def long_preferred_email?
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
