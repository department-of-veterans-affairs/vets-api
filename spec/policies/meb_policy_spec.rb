# frozen_string_literal: true

require 'rails_helper'
describe MebPolicy do
  subject { described_class }

  permissions :access? do
    context 'when user has an ICN, SSN, and is LOA3' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :my_education_benefits)
      end

      it 'increments the StatsD success counter' do
        expect do
          MebPolicy.new(user,
                        :my_education_benefits).access?
        end.to trigger_statsd_increment('api.my_education_benefits.policy.success')
      end
    end

    context 'when user does not have an ICN, SSN, or is not LOA3' do
      let(:user) { build(:user, :loa1) }

      before do
        user.identity.attributes = {
          icn: nil,
          ssn: nil
        }
      end

      it 'denies access' do
        expect(subject).not_to permit(user, :my_education_benefits)
      end

      it 'increments the StatsD failure counter' do
        expect do
          MebPolicy.new(user,
                        :my_education_benefits).access?
        end.to trigger_statsd_increment('api.my_education_benefits.policy.failure')
      end
    end
  end
end
