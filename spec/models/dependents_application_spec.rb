# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DependentsApplication, type: :model do
  let(:dependents_application) { create(:dependents_application) }

  describe '.filter_children' do
    it 'filters children to match dependents' do
      dependents = [
        {
          'childSocialSecurityNumber' => '111223333'
        }
      ]
      children = [
        {
          'ssn' => '111-22-3334'
        },
        {
          'ssn' => '111-22-3333'
        }
      ]

      expect(described_class.filter_children(dependents, children)).to eq(
        [{ 'ssn' => '111-22-3333' }]
      )
    end
  end

  describe '.transform_form' do
    context 'spouse and children have ssns' do
      it 'merges the evss and submitted forms' do
        form = described_class.transform_form(dependents_application.parsed_form, get_fixture('dependents/retrieve'))
        expect(form).to eq(get_fixture('dependents/transform_form'))
      end
    end

    context 'spouse and children dont have ssns' do
      let(:dependents_application) { build(:dependents_application) }

      before do
        form = dependents_application.parsed_form
        form['dependents'].each do |dependent|
          dependent.delete('childSocialSecurityNumber')
          dependent['childHasNoSsnReason'] = 'NONRESIDENTALIEN'
          dependent['childHasNoSsn'] = true
        end

        form['currentMarriage'].tap do |current_marriage|
          current_marriage.delete('spouseSocialSecurityNumber')
          current_marriage['spouseHasNoSsnReason'] = 'NONRESIDENTALIEN'
          current_marriage['spouseHasNoSsn'] = true
        end

        dependents_application.form = form.to_json
        dependents_application.instance_variable_set(:@parsed_form, nil)
        dependents_application.save!
      end

      it 'merges the forms' do
        form = described_class.transform_form(dependents_application.parsed_form, get_fixture('dependents/retrieve'))
        expect(form).to eq(get_fixture('dependents/no_ssn_transform'))
      end
    end
  end

  describe '#user_can_access_evss' do
    it 'does not allow users who dont have evss access' do
      dependents_application = DependentsApplication.new(user: create(:user))
      expect_attr_invalid(dependents_application, :user, 'must have evss access')
    end

    it 'allows evss users' do
      dependents_application = DependentsApplication.new(user: create(:evss_user))
      expect_attr_valid(dependents_application, :user)
    end
  end
end
