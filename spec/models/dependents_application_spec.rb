# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplication, type: :model do
  let(:dependents_application) { create(:dependents_application) }

  it 'test' do
    user = create(:evss_user)
    VCR.configure do |c|
      c.allow_http_connections_when_no_cassette = true
    end
    dependents_application = create(:dependents_application)
    binding.pry; fail
    EVSS::DependentsApplicationJob.new.perform(dependents_application.id, dependents_application.parsed_form, user.uuid)
  end

  describe '.convert_phone' do
    it 'should convert a phone to the evss format' do
      expect(described_class.convert_phone('1234567890', 'DAYTIME')).to eq(
        {
          'areaNbr' => '123',
          'phoneType' => 'DAYTIME',
          'phoneNbr' => '456-7890'
        }
      )
    end
  end

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

  describe '.transform_form' do
    it 'should merge the evss and submitted forms' do
      form = described_class.transform_form(dependents_application.parsed_form, get_fixture('dependents/retrieve'))
      expect(form).to eq(get_fixture('dependents/transform_form'))
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
