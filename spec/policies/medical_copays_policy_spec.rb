# frozen_string_literal: true

require 'rails_helper'

describe MedicalCopaysPolicy do
  subject { described_class }

  permissions :access? do
    context 'with the mcp feature enabled' do
      context 'with a user who has the required mcp attributes' do
        let(:user) { build(:user, :loa3) }

        it 'grants access' do
          allow(Flipper).to receive(:enabled?).with('show_medical_copays', user).and_return(true)

          expect(subject).to permit(user, :mcp)
        end

        it 'increments statsD success' do
          expect { MedicalCopaysPolicy.new(user, :mcp).access? }.to trigger_statsd_increment('api.mcp.policy.success')
        end
      end

      context 'with a user who does not have the required mcp attributes' do
        let(:user) { build(:user, :loa1) }

        before do
          user.identity.attributes = {
            icn: nil,
            edipi: nil
          }
        end

        it 'denies access' do
          allow(Flipper).to receive(:enabled?).with('show_medical_copays', user).and_return(true)

          expect(subject).not_to permit(user, :mcp)
        end

        it 'increments statsD failure' do
          expect { MedicalCopaysPolicy.new(user, :mcp).access? }.to trigger_statsd_increment('api.mcp.policy.failure')
        end
      end
    end

    context 'with the mcp feature disabled' do
      context 'with a user who has the required mcp attributes' do
        let(:user) { build(:user, :loa3) }

        it 'grants access' do
          allow(Flipper).to receive(:enabled?).with('show_medical_copays', user).and_return(false)

          expect(subject).not_to permit(user, :mcp)
        end
      end

      context 'with a user who does not have the required mcp attributes' do
        let(:user) { build(:user, :loa1) }

        before do
          user.identity.attributes = {
            icn: nil,
            edipi: nil
          }
        end

        it 'denies access' do
          allow(Flipper).to receive(:enabled?).with('show_medical_copays', user).and_return(false)

          expect(subject).not_to permit(user, :mcp)
        end
      end
    end
  end
end
