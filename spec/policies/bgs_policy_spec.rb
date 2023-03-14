# frozen_string_literal: true

require 'rails_helper'

describe BGSPolicy do
  subject { described_class }

  permissions :access? do
    context 'with a user who has the required bgs attributes' do
      let(:user) { build(:user, :loa3) }

      it 'grants access' do
        expect(subject).to permit(user, :bgs)
      end

      it 'increments the StatsD success counter' do
        expect { BGSPolicy.new(user, :bgs).access? }.to trigger_statsd_increment('api.bgs.policy.success')
      end

      context 'and sets log_stats to false' do
        it 'does not increment the StatsD success counter' do
          policy = BGSPolicy.new(user, :bgs).access?(log_stats: false)
          expect { policy }.not_to trigger_statsd_increment('api.bgs.policy.success')
        end
      end
    end

    context 'with a user who does not have the required bgs attributes' do
      let(:user) { build(:user, :loa3, ssn: nil, participant_id: nil, icn: nil) }

      it 'denies access' do
        expect(subject).not_to permit(user, :bgs)
      end

      it 'increments the StatsD failure counter' do
        expect { BGSPolicy.new(user, :bgs).access? }.to trigger_statsd_increment('api.bgs.policy.failure')
      end

      context 'and sets log_stats to false' do
        it 'does not increment the StatsD success counter' do
          policy = BGSPolicy.new(user, :bgs).access?(log_stats: false)
          expect { policy }.not_to trigger_statsd_increment('api.bgs.policy.failure')
        end
      end
    end
  end
end
