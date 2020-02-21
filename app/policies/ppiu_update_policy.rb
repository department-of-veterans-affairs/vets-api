# frozen_string_literal: true

PPIUUpdatePolicy = Struct.new(:user, :ppiu_update) do
  def access?
    res = EVSS::PPIU::Service.new(user).get_payment_information
    control_information = res.responses.first.control_information

    control_information.is_competent_indicator && control_information.no_fiduciary_assigned_indicator
  end
end
