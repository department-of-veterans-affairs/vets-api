# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ApplicationPolicy do
  let(:user) { double('User') }
  let(:record) { double('Record') }
  let(:policy) { described_class.new(user, record) }
  let(:mock_logger) { instance_double(SemanticLogger::Logger, warn: nil) }

  before do
    # Mock the logger used by the policy
    allow(Rails).to receive(:logger).and_return(mock_logger)
  end

  describe 'default permissions' do
    it 'disallows all actions by default' do
      expect(policy.index?).to be(false)
      expect(policy.show?).to be(false)
      expect(policy.create?).to be(false)
      expect(policy.new?).to be(false)
      expect(policy.update?).to be(false)
      expect(policy.edit?).to be(false)
      expect(policy.destroy?).to be(false)
    end
  end

  describe 'logging for default methods' do
    it 'logs a warning for #index?' do
      policy.index?
      expect(mock_logger).to have_received(:warn).with(/is using the default #index\? implementation/)
    end

    it 'logs a warning for #show?' do
      policy.show?
      expect(mock_logger).to have_received(:warn).with(/is using the default #show\? implementation/)
    end

    it 'logs a warning for #create?' do
      policy.create?
      expect(mock_logger).to have_received(:warn).with(/is using the default #create\? implementation/)
    end

    it 'logs a warning for #update?' do
      policy.update?
      expect(mock_logger).to have_received(:warn).with(/is using the default #update\? implementation/)
    end

    it 'logs a warning for #destroy?' do
      policy.destroy?
      expect(mock_logger).to have_received(:warn).with(/is using the default #destroy\? implementation/)
    end
  end

  describe '#new?' do
    it 'delegates to #create?' do
      allow(policy).to receive(:create?).and_return(true)
      expect(policy.new?).to be(true)
    end
  end

  describe '#edit?' do
    it 'delegates to #update?' do
      allow(policy).to receive(:update?).and_return(true)
      expect(policy.edit?).to be(true)
    end
  end

  describe 'Scope' do
    let(:scope) { double('Scope') }
    let(:policy_scope) { AccreditedRepresentativePortal::ApplicationPolicy::Scope.new(user, scope) }

    describe '#resolve' do
      it 'raises an error if not implemented' do
        expect { policy_scope.resolve }.to raise_error(NoMethodError, /You must define #resolve in/)
      end
    end
  end
end
