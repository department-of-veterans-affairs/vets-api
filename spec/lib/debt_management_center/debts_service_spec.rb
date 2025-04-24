# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debts_service'
require 'debt_management_center/models/debt_store'
require_relative 'shared_examples/debt_service_examples'

RSpec.describe DebtManagementCenter::DebtsService do
  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:user_no_ssn) { build(:user, :loa3, ssn: '') }

  describe '#get_debts' do
    it_behaves_like 'debt service behavior'
  end

  describe '#get_debt_by_id' do
    let(:user) { build(:user, :loa3) }
    let(:debt_id) { '944147b0-7ec0-4a81-ab40-a437b5ce5353' }

    context 'when debt is missing from redis' do
      it 'raises an error' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            expect { service.get_debt_by_id(debt_id) }.to raise_error do |error|
              expect(error).to be_instance_of(described_class::DebtNotFound)
            end
          end
        end
      end
    end

    context 'with logged in user' do
      it 'downloads the pdf' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            service = described_class.new(user)
            debts = service.get_debts[:debts]
            debts.map { |d| d['id'] = SecureRandom.uuid }
            debts[0]['id'] = debt_id
            debt_store = DebtManagementCenter::DebtStore.find_or_build(user.uuid)
            debt_store.update(debts:, uuid: user.uuid)
            expect(service.get_debt_by_id(debt_id).to_json).to eq(
              get_fixture('dmc/debt').to_json
            )
          end
        end
      end
    end
  end
end
