# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplication, type: :model do
  describe '#user_can_access_evss' do
    it 'should not allow users who dont have evss access' do
      dependents_application = DependentsApplication.new(user: create(:user))
      expect_attr_invalid(dependents_application, :user, 'must have evss access')
    end
  end
end
