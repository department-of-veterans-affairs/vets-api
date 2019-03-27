# frozen_string_literal: true

require 'rails_helper'

describe Form526Policy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required form526 attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :form526)
      end

      it 'increments the StatsD success counter' do
        expect { EVSSPolicy.new(user, :evss).access? }.to trigger_statsd_increment('api.evss.policy.success')
      end
    end

    context 'with a user who does not have the required form526 attributes' do
      let(:user) { build(:unauthorized_evss_user, :loa3) }

      it 'denies access' do
        expect(subject).to_not permit(user, :form526)
      end

      it 'increments the StatsD failure counter' do
        expect { EVSSPolicy.new(user, :evss).access? }.to trigger_statsd_increment('api.evss.policy.failure')
      end
    end
  end
end
