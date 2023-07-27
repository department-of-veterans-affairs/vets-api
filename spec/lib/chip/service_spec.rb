# frozen_string_literal: true

require 'rails_helper'
require 'chip/service'

describe Chip::Service do
  describe '#initialize' do
    let(:test_username) { 'test_user_name' }
    let(:test_tenant_name) { 'mobile_app' }
    let(:test_tenant_id) { '6f1c8b41-9c77-469d-852d-269c51a7d380' }
    let(:test_password) { 'test_password' }
    let(:expected_error) { ArgumentError }

    context 'When username does not exist' do
      let(:expected_error_message) { 'Invalid username' }

      it 'raises validation error nil username' do
        expect do
          described_class.new(tenant_id: :test_tenant_id, tenant_name: :test_tenant_name, username: nil,
                              password: :test_password)
        end.to raise_exception(expected_error, expected_error_message)
      end

      it 'raises validation error for empty username' do
        expect do
          described_class.new(tenant_id: :test_tenant_id, tenant_name: :test_tenant_name, username: '',
                              password: :test_password)
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'When password does not exist' do
      let(:expected_error_message) { 'Invalid password' }

      it 'raises validation error for nil password' do
        expect do
          described_class.new(tenant_id: :test_tenant_id, tenant_name: :test_tenant_name, username: :test_username,
                              password: nil)
        end.to raise_exception(expected_error, expected_error_message)
      end

      it 'raises validation error for empty password' do
        expect do
          described_class.new(tenant_id: :test_tenant_id, tenant_name: :test_tenant_name, username: :test_username,
                              password: '')
        end.to raise_exception(expected_error, expected_error_message)
      end
    end

    context 'When tenant_name is not valid' do
      let(:expected_invalid_error_message) { 'Invalid tenant parameters' }
      let(:expected_no_exist_error_message) { 'Tenant parameters do not exist' }

      it 'raises validation error for nil tenant_name' do
        expect do
          described_class.new(tenant_id: test_tenant_id, tenant_name: nil, username: :test_username,
                              password: :test_password)
        end.to raise_exception(expected_error, expected_invalid_error_message)
      end

      it 'raises validation error for empty tenant_name' do
        expect do
          described_class.new(tenant_id: test_tenant_id, tenant_name: '', username: :test_username,
                              password: :test_password)
        end.to raise_exception(expected_error, expected_invalid_error_message)
      end

      it 'raises validation error for tenant_name that does not exist' do
        expect do
          described_class.new(tenant_id: test_tenant_id, tenant_name: 'test_tenant_name', username: :test_username,
                              password: :test_password)
        end.to raise_exception(expected_error, expected_no_exist_error_message)
      end
    end

    context 'When tenant_id is not valid' do
      let(:expected_invalid_error_message) { 'Invalid tenant parameters' }
      let(:expected_no_exist_error_message) { 'Tenant parameters do not exist' }

      it 'raises validation error for nil tenant_id' do
        expect do
          described_class.new(tenant_id: nil, tenant_name: test_tenant_name, username: test_username,
                              password: test_password)
        end.to raise_exception(expected_error, expected_invalid_error_message)
      end

      it 'raises validation error for empty tenant_id' do
        expect do
          described_class.new(tenant_id: '', tenant_name: test_tenant_name, username: test_username,
                              password: test_password)
        end.to raise_exception(expected_error, expected_invalid_error_message)
      end

      it 'raises validation error invalid tenant_id that does not exist' do
        expect do
          described_class.new(tenant_id: 'test_tenant_id', tenant_name: test_tenant_name, username: test_username,
                              password: test_password)
        end.to raise_exception(expected_error, expected_no_exist_error_message)
      end
    end

    context 'When called with valid parameters' do
      it 'creates service object' do
        expect(described_class.new(tenant_id: test_tenant_id, tenant_name: test_tenant_name,
                                   username: :test_username,
                                   password: :test_password)).to be_a(Chip::Service)
      end
    end
  end
end
