# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/models/communication_permission'

describe VAProfile::Models::CommunicationPermission, type: :model do
  describe 'validation' do
    let(:communication_permission) { described_class.new(allowed: true) }

    context 'allowed' do
      it 'validates presence of allowed' do
        communication_permission.allowed = nil
        expect_attr_invalid(communication_permission, :allowed, 'must be set')
      end
    end

    context 'sensitive' do
      it 'validates inclusion when sensitive is true or false' do
        [true, false].each do |sensitive_value|
          communication_permission.sensitive = sensitive_value
          expect(communication_permission).to be_valid
        end
      end

      it 'skips validation when sensitive is nil or blank' do
        [nil, ''].each do |sensitive_value|
          communication_permission.sensitive = sensitive_value
          expect(communication_permission).to be_valid
        end
      end
    end
  end
end
