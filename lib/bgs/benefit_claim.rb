# frozen_string_literal: true

require 'bgs/utilities/helpers'
require 'vets/shared_logging'
require_relative 'service'
module BGS
  class BenefitClaim
    include Vets::SharedLogging
    include BGS::Utilities::Helpers

    BENEFIT_CLAIM_PARAM_CONSTANTS = {
      benefit_claim_type: '1',
      payee: '00',
      disposition: 'M',
      section_unit_no: '555',
      folder_with_claim: 'N',
      pre_discharge_indicator: 'N'
    }.freeze

    def initialize(args:)
      @vnp_benefit_claim = args[:vnp_benefit_claim]
      @veteran = args[:veteran]
      @user = args[:user]
      @proc_id = args[:proc_id]
      @end_product_name = args[:end_product_name]
      @end_product_code = args[:end_product_code]
    end

    def create
      benefit_claim = bgs_service.insert_benefit_claim(benefit_claim_params)

      {
        benefit_claim_id: benefit_claim.dig(:benefit_claim_record, :benefit_claim_id),
        claim_type_code: benefit_claim.dig(:benefit_claim_record, :claim_type_code),
        participant_claimant_id: benefit_claim.dig(:benefit_claim_record, :participant_claimant_id),
        program_type_code: benefit_claim.dig(:benefit_claim_record, :program_type_code),
        service_type_code: benefit_claim.dig(:benefit_claim_record, :service_type_code),
        status_type_code: benefit_claim.dig(:benefit_claim_record, :status_type_code)
      }
    rescue => e
      handle_error(e, __method__.to_s)
    end

    private

    # rubocop:disable Metrics/MethodLength
    def benefit_claim_params
      {
        file_number: @veteran[:file_number],
        ssn: @user[:ssn],
        ptcpnt_id_claimant: @user[:participant_id],
        end_product: @veteran[:benefit_claim_type_end_product],
        first_name: normalize_name(@user[:first_name]),
        last_name: normalize_name(@user[:last_name]),
        address_line1: @veteran[:address_line_one],
        address_line2: @veteran[:address_line_two],
        address_line3: @veteran[:address_line_three],
        city: @veteran[:address_city],
        state: @veteran[:address_state_code],
        postal_code: @veteran[:address_zip_code],
        address_type: @veteran[:address_type],
        mlty_postal_type_cd: @veteran[:mlty_postal_type_cd],
        mlty_post_office_type_cd: @veteran[:mlty_post_office_type_cd],
        foreign_mail_code: @veteran[:foreign_mail_code],
        email_address: @veteran[:email_address],
        country: @veteran[:address_country],
        date_of_claim: Time.current.strftime('%m/%d/%Y'),
        end_product_name: @end_product_name,
        end_product_code: @end_product_code,
        soj: @veteran[:regional_office_number]
      }.merge(BENEFIT_CLAIM_PARAM_CONSTANTS)
    end
    # rubocop:enable Metrics/MethodLength

    def normalize_name(name)
      remove_special_characters_from_name(normalize_composite_characters(name))
    end

    def handle_error(error, method)
      bgs_service.update_manual_proc(@proc_id)

      bgs_service.notify_of_service_exception(error, method)
    end

    def bgs_service
      @bgs_service ||= BGS::Service.new(@user)
    end
  end
end
