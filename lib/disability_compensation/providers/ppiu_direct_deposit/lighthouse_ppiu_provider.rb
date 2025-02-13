# frozen_string_literal: true

require 'disability_compensation/providers/ppiu_direct_deposit/ppiu_provider'
require 'disability_compensation/responses/payment_information_response'
require 'lighthouse/direct_deposit/client'

class LighthousePPIUProvider
  include PPIUProvider

  def initialize(current_user)
    @service = DirectDeposit::Client.new(current_user.icn)
  end

  def get_payment_information(_lighthouse_client_id = nil, _lighthouse_rsa_key_path = nil)
    data = @service.get_payment_info
    # return value of get_payment_info is a hash with symbols.
    # Lighthouse::DirectDeposit::Response
    # transform accordingly
    transform(data)
  end

  private

  def transform(data)
    DisabilityCompensation::ApiProvider::PaymentInformationResponse.new(
      responses: [
        DisabilityCompensation::ApiProvider::PaymentInformation.new(
          control_information: populate_control_information(data),
          payment_account: populate_payment_account(data)
        )
      ]
    )
  end

  def populate_control_information(data)
    return {} if data&.control_information.blank?

    DisabilityCompensation::ApiProvider::ControlInformation.new(
      can_update_address: false,
      corp_avail_indicator: data.control_information[:is_corp_available],
      corp_rec_found_indicator: data.control_information[:is_corp_rec_found],
      has_no_bdn_payments_indicator: data.control_information[:has_no_bdn_payments],
      identity_indicator: data.control_information[:has_identity],
      is_competent_indicator: data.control_information[:is_competent],
      index_indicator: data.control_information[:has_index],
      no_fiduciary_assigned_indicator: data.control_information[:has_no_fiduciary_assigned],
      not_deceased_indicator: data.control_information[:is_not_deceased]
    )
  end

  def populate_payment_account(data)
    return {} if data&.payment_account.blank?

    DisabilityCompensation::ApiProvider::PaymentAccount.new(
      account_type: data.payment_account[:account_type],
      financial_institution_name: data.payment_account[:name],
      account_number: data.payment_account[:account_number],
      financial_institution_routing_number: data.payment_account[:routing_number]
    )
  end
end
