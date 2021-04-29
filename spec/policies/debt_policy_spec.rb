# frozen_string_literal: true

require 'rails_helper'

describe DebtPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required debt attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :debt)
      end

      it 'increments the StatsD success counter' do
        expect { DebtPolicy.new(user, :debt).access? }.to trigger_statsd_increment('api.debt.policy.success')
      end
    end

    context 'with a user who does not have the required debt attributes' do
      let(:user) { build(:user, :loa1) }

      before do
        user.identity.attributes = {
          icn: nil,
          ssn: nil
        }
      end

      it 'denies access' do
        expect(subject).not_to permit(user, :debt)
      end

      it 'increments the StatsD failure counter' do
        expect { DebtPolicy.new(user, :debt).access? }.to trigger_statsd_increment('api.debt.policy.failure')
      end
    end
  end
end
