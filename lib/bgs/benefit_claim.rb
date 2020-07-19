# frozen_string_literal: true

module BGS
  class BenefitClaim < Service
    def initialize(vnp_benefit_claim:, veteran:, user:)
      @vnp_benefit_claim = vnp_benefit_claim
      @veteran = veteran

      super(user)
    end

    def create
      benefit_claim = insert_benefit_claim(@vnp_benefit_claim)

      {
        benefit_claim_id: benefit_claim.dig(:benefit_claim_record, :benefit_claim_id),
        claim_type_code: benefit_claim.dig(:benefit_claim_record, :claim_type_code),
        participant_claimant_id: benefit_claim.dig(:benefit_claim_record, :participant_claimant_id),
        program_type_code: benefit_claim.dig(:benefit_claim_record, :program_type_code),
        service_type_code: benefit_claim.dig(:benefit_claim_record, :service_type_code),
        status_type_code: benefit_claim.dig(:benefit_claim_record, :status_type_code)
      }
    end

    private

    def insert_benefit_claim(_vnp_benefit_claim)
      with_multiple_attempts_enabled do
        service.claims.insert_benefit_claim(
          benefit_claim_params
        )
      end
    end

    # rubocop:disable Metrics/MethodLength
    def benefit_claim_params
      {
        file_number: @veteran[:file_number],
        ssn: @user[:ssn],
        ptcpnt_id_claimant: @user[:participant_id],
        benefit_claim_type: '1',
        payee: '00',
        end_product: @veteran[:benefit_claim_type_end_product],
        end_product_code: '130DPNEBNADJ',
        first_name: @user[:first_name],
        last_name: @user[:last_name],
        address_line1: @veteran[:address_line_one],
        address_line2: @veteran[:address_line_two],
        address_line3: @veteran[:address_line_three],
        city: @veteran[:address_city],
        state: @veteran[:address_state_code],
        postal_code: @veteran[:address_zip_code],
        email_address: @veteran[:email_address],
        country: @veteran[:address_country],
        disposition: 'M',
        section_unit_no: '555',
        folder_with_claim: 'N',
        end_product_name: '130 - Automated Dependency 686c',
        pre_discharge_indicator: 'N',
        date_of_claim: Time.current.strftime('%m/%d/%Y')
      }
    end
    # rubocop:enable Metrics/MethodLength
  end
end
