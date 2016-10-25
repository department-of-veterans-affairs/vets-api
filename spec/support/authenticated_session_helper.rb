# frozen_string_literal: true
module AuthenticatedSessionHelper
  def use_authenticated_current_user(options = {})
    klass = options[:klass] || ApplicationController
    current_user = options[:current_user] || build(:loa3_user)

    expect_any_instance_of(klass)
      .to receive(:authenticate_token).and_return(:true)
    expect_any_instance_of(klass)
      .to receive(:current_user).and_return(current_user)
  end
end
