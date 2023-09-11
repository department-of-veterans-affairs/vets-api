# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debts_service'
require 'debt_management_center/models/debt_store'

RSpec.describe DebtManagementCenter::DebtsService do
  let(:file_number) { '796043735' }
  let(:user) { build(:user, :loa3, ssn: file_number) }
  let(:user_no_ssn) { build(:user, :loa3, ssn: '') }

  describe '#get_letters' do
    context 'with a valid file number' do
      it 'fetches the veterans debt data' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            res = described_class.new(user).get_debts
            expect(JSON.parse(res.to_json)['debts'][0]['fileNumber']).to eq('796043735')
          end
        end
      end
    end

    context 'without a valid file number' do
      it 'returns a bad request error' do
        VCR.use_cassette('bgs/people_service/no_person_data') do
          VCR.use_cassette('debts/get_letters_empty_ssn', VCR::MATCH_EVERYTHING) do
            expect(StatsD).to receive(:increment).once.with(
              'api.dmc.init_debts.fail', tags: [
                'error:CommonClientErrorsClientError', 'status:400'
              ]
            )
            expect(StatsD).to receive(:increment).once.with(
              'api.dmc.init_debts.total'
            )
            expect(Raven).to receive(:tags_context).once.with(external_service: described_class.to_s.underscore)
            expect(Raven).to receive(:extra_context).once.with(
              url: Settings.dmc.url,
              message: 'the server responded with status 400',
              body: { 'message' => 'Bad request' }
            )
            expect { described_class.new(user_no_ssn).get_debts }.to raise_error(
              Common::Exceptions::BackendServiceException
            ) do |e|
              expect(e.message).to match(/DMC400/)
            end
          end
        end
      end
    end

    context 'empty DMC response' do
      it 'handles an empty payload' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_empty_response', VCR::MATCH_EVERYTHING) do
            res = described_class.new(user).get_debts
            expect(JSON.parse(res.to_json)['debts']).to eq([])
          end
        end
      end
    end
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
