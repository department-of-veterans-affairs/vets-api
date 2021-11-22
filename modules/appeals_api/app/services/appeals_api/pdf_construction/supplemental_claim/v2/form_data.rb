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

          delegate :veteran_first_name, :veteran_middle_initial, :veteran_last_name, :ssn, :file_number,
                   :full_name, :veteran_dob_month, :veteran_dob_year, :veteran_dob_day, :veteran_service_number,
                   :insurance_policy_number, :mailing_address_number_and_street,
                   :mailing_address_apartment_or_unit_number, :mailing_address_city_and_box, :mailing_address_state,
                   :mailing_address_country, :zip_code_5, :phone, :email, :contestable_issues, :soc_opt_in,
                   :new_evidence_locations, :new_evidence_dates, :date_signed,
                   to: :supplemental_claim

          def ssn_first_three
            ssn.first(3)
          end

          def ssn_middle_two
            ssn[3..4]
          end

          def ssn_last_four
            ssn.last(4)
          end

          def benefit_type
            benefit_type_form_codes[supplemental_claim.benefit_type]
          end

          def soc_ssoc_opt_in
            soc_opt_in ? 1 : 'Off'
          end

          def soc_date_text(issue)
            date = issue.soc_date_formatted

            return '' unless date

            "SOC/SSOC Date: #{date}"
          end

          def notice_acknowledgement
            supplemental_claim.notice_acknowledgement ? 1 : 'Off'
          end

          def signature_of_veteran_claimant_or_rep
            "#{full_name[0...180]} - Signed by digital authentication to api.va.gov"
          end

          def print_name_veteran_claimaint_or_rep
            full_name[0...180]
          end

          def stamp_text
            "#{veteran_last_name.truncate(35)} - #{ssn_last_four}"
          end

          def new_evidence_locations
            evidence_records.map(&:location)
          end

          def new_evidence_dates
            evidence_records.map(&:dates)
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
              'pension_survivors_benefits' => 2,
              'fiduciary' => 3,
              'insurance' => 4,
              'education' => 5,
              'readiness_and_employment' => 6,
              'loan guaranty' => 7,
              'vha' => 8,
              'nca' => 9
            }
          end
        end
      end
    end
  end
end
