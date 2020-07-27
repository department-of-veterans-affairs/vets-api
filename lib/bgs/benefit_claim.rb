# frozen_string_literal: true

module BGS
  class BenefitClaim
    BENEFIT_CLAIM_PARAM_CONSTANTS = {
      benefit_claim_type: '1',
      payee: '00',
      disposition: 'M',
      section_unit_no: '555',
      folder_with_claim: 'N',
      end_product_name: '130 - Automated Dependency 686c',
      pre_discharge_indicator: 'N',
      end_product_code: '130DPNEBNADJ'
    }.freeze

    def initialize(vnp_benefit_claim:, veteran:, user:, proc_id:)
      @vnp_benefit_claim = vnp_benefit_claim
      @veteran = veteran
      @user = user
      @proc_id = proc_id
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

    def insert_benefit_claim(_vnp_benefit_claim)
      bgs_service.claims.insert_benefit_claim(
        benefit_claim_params
      )
    rescue => e
      handle_error(e, __method__.to_s)
    end

    def benefit_claim_params
      {
        file_number: @veteran[:file_number],
        ssn: @user[:ssn],
        ptcpnt_id_claimant: @user[:participant_id],
        end_product: @veteran[:benefit_claim_type_end_product],
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
        date_of_claim: Time.current.strftime('%m/%d/%Y')
      }.merge(BENEFIT_CLAIM_PARAM_CONSTANTS)
    end

    private

    def handle_error(error, method)
      update_manual_proc
      bgs_service.notify_of_service_exception(error, method)
    end

    def update_manual_proc
      bgs_service.vnp_proc_v2.vnp_proc_update(
        {
          vnp_proc_id: @proc_id,
          vnp_proc_state_type_cd: 'Manual'
        }.merge(bgs_service.bgs_auth)
      )
    rescue => e
      bgs_service.notify_of_service_exception(e, __method__)
    end

    def bgs_service
      @bgs_service ||= BGS::Services.new(
        external_uid: @user[:icn],
        external_key: @user[:external_key]
      )
    end
  end
end
