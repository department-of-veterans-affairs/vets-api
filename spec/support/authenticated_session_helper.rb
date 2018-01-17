# frozen_string_literal: true

module AuthenticatedSessionHelper
  def use_authenticated_current_user(options = {})
    current_user = options[:current_user] || build(:user)

    expect_any_instance_of(ApplicationController)
      .to receive(:authenticate_token).at_least(:once).and_return(:true)
    expect_any_instance_of(ApplicationController)
      .to receive(:current_user).at_least(:once).and_return(current_user)
  end
end
