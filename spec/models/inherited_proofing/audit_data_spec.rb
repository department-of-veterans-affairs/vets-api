# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InheritedProofing::AuditData, type: :model do
  let(:audit_data) { InheritedProofing::AuditData.new(user_uuid:, code:, legacy_csp:) }
  let(:user_uuid) { SecureRandom.uuid }
  let(:code) { SecureRandom.hex }
  let(:legacy_csp) { 'mhv' }
  let(:error) { Common::Exceptions::ValidationErrors }
  let(:error_message) { 'Validation error' }

  describe 'validations' do
    context 'user_uuid' do
      let(:user_uuid) { nil }

      it 'will return validation error if nil' do
        expect { audit_data.save! }.to raise_error(error, error_message)
      end
    end

    context 'code' do
      let(:code) { nil }

      it 'will return validation error if nil' do
        expect { audit_data.save! }.to raise_error(error, error_message)
      end
    end

    context 'legacy_csp' do
      let(:legacy_csp) { nil }

      it 'will return error message if nil' do
        expect { audit_data.save! }.to raise_error(error, error_message)
      end
    end
  end
end
