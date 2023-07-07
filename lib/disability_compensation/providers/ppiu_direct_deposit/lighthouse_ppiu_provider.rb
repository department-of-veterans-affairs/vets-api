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
    # TODO: Implement in #59698
    # data = @service.get_payment_info
    # transform(data)

    raise NotImplementedError, 'Lighthouse PPIU/Direct Deposit Provider not implemented yet'
  end

  private

  def transform(_data)
    # TODO: Implement in #59695
    # TODO: This will return a Generic PaymentInformation Response
    raise NotImplementedError, 'Lighthouse PPIU/Direct Deposit Provider not implemented yet'
  end
end
