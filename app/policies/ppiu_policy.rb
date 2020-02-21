# frozen_string_literal: true

PPIUPolicy = Struct.new(:user, :ppiu) do
  def access?
    user.loa3? && user.multifactor
  end

  def access_update?
    res = EVSS::PPIU::Service.new(user).get_payment_information
    control_information = res.responses.first.control_information

    control_information.is_competent_indicator && control_information.no_fiduciary_assigned_indicator
  end
end
