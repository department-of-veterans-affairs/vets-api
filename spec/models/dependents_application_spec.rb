# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplication, type: :model do
  describe '.filter_children' do
    it 'should filter children to match dependents' do
      dependents = [
        {
          'childSocialSecurityNumber' => '111223333'
        }
      ]
      children = [
        {
          "ssn" => "111-22-3334",
        },
        {
          "ssn" => "111-22-3333",
        }
      ]

      expect(described_class.filter_children(dependents, children)).to eq(
        [{"ssn"=>"111-22-3333"}]
      )
    end
  end

  describe '#user_can_access_evss' do
    it 'should not allow users who dont have evss access' do
      dependents_application = DependentsApplication.new(user: create(:user))
      expect_attr_invalid(dependents_application, :user, 'must have evss access')
    end

    it 'should allow evss users' do
      dependents_application = DependentsApplication.new(user: create(:evss_user))
      expect_attr_valid(dependents_application, :user)
    end
  end
end
