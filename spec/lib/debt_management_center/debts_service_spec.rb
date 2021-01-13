# frozen_string_literal: true

require 'rails_helper'
require 'debt_management_center/debts_service'

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
  end
end
