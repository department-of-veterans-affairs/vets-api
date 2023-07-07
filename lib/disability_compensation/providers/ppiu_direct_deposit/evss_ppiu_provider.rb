# frozen_string_literal: true

require 'disability_compensation/providers/ppiu_direct_deposit/ppiu_provider'
require 'evss/ppiu/service'

class EvssPPIUProvider
  include PPIUProvider
  def initialize(current_user)
    @service = EVSS::PPIU::Service.new(current_user)
  end

  def get_payment_information(_client_id = nil, _rsa_key_path = nil)
    @service.get_payment_information
  end
end
