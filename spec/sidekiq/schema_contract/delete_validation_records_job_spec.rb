# frozen_string_literal: true

require 'rails_helper'
require_relative Rails.root.join('app', 'models', 'schema_contract', 'validation_initiator')

RSpec.describe SchemaContract::DeleteValidationRecordsJob do
  let(:job) { described_class.new }
  let(:response) do
    OpenStruct.new({ success?: true, status: 200, body: { key: 'value' } })
  end

  context 'when records exist that are over a month old' do
    let!(:old_contract) do
      create(:schema_contract_validation, contract_name: 'test_index', user_uuid: '1234', response:,
                                          status: 'initialized', updated_at: 1.month.ago - 2.days)
    end
    let!(:new_contract) do
      create(:schema_contract_validation, contract_name: 'test_index', user_uuid: '1234', response:,
                                          status: 'initialized')
    end

    it 'removes old records' do
      job = SchemaContract::DeleteValidationRecordsJob.new
      job.perform

      expect { old_contract.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { new_contract.reload }.not_to raise_error
    end
  end
end
