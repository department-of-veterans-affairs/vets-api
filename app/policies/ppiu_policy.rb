# frozen_string_literal: true

require 'evss/ppiu/service'

PPIUPolicy = Struct.new(:user, :ppiu) do
  def access?
    user.loa3? && user.multifactor
  end

  def access_update?
    res = EVSS::PPIU::Service.new(user).get_payment_information

    res.responses.first.control_information.authorized?
  end
end
