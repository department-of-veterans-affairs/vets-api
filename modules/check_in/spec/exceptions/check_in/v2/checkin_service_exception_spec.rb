# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CheckIn::V2::CheckinServiceException do
  subject { described_class }

  let(:error_message) do
    { error: 'lastname does not match with current record' }
  end
  let(:status) { '401' }
  let(:checkin_service_exception) do
    subject.new(status: '401', original_body: error_message)
  end
  let(:cie_exception_code) { 'CIE-VETS-API_' }
  let(:response_value) { { status:, detail: [error_message], code: cie_exception_code + status } }

  describe '.build' do
    it 'returns an instance of cie exception' do
      expect(checkin_service_exception).to be_an_instance_of(CheckIn::V2::CheckinServiceException)
    end
  end

  describe 'checkin_service_exception' do
    it 'returns exception with CIE-VETS-API in key' do
      expect(checkin_service_exception.key).to eq(cie_exception_code + status)
    end

    it 'returns exception with error_message in original_body' do
      expect(checkin_service_exception.original_body).to eq(error_message)
    end

    it 'returns exception with CIE-VETS-API error code in response_values' do
      expect(checkin_service_exception.response_values).to eq(response_value)
    end

    it 'returns exception with status in original_status' do
      expect(checkin_service_exception.original_status).to eq(status)
    end
  end
end
