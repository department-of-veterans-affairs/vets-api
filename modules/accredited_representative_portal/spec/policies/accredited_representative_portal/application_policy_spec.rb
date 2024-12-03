# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AccreditedRepresentativePortal::ApplicationPolicy do
  let(:user) { double('User') }
  let(:record) { double('Record') }
  let(:policy) { described_class.new(user, record) }

  describe '#initialize' do
    it 'assigns the user and record' do
      expect(policy.user).to eq(user)
      expect(policy.record).to eq(record)
    end
  end

  describe 'default permissions' do
    it 'disallows all actions by default' do
      expect(policy.index?).to eq(false)
      expect(policy.show?).to eq(false)
      expect(policy.create?).to eq(false)
      expect(policy.new?).to eq(false)
      expect(policy.update?).to eq(false)
      expect(policy.edit?).to eq(false)
      expect(policy.destroy?).to eq(false)
    end
  end

  describe '#new?' do
    it 'delegates to #create?' do
      allow(policy).to receive(:create?).and_return(true)
      expect(policy.new?).to eq(true)
    end
  end

  describe '#edit?' do
    it 'delegates to #update?' do
      allow(policy).to receive(:update?).and_return(true)
      expect(policy.edit?).to eq(true)
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
