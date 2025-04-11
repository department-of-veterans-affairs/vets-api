# frozen_string_literal: true

RSpec.shared_examples 'debt service behavior' do
  before do
    allow(StatsD).to receive(:increment)
  end

  describe '#get_debts' do
    context 'with a valid file number' do
      it 'fetches the veterans debt data' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            res = described_class.new(user).get_debts
            parsed_response = JSON.parse(res.to_json)['debts'][0]
            expect(parsed_response['fileNumber']).to eq('796043735')
            expect(parsed_response['compositeDebtId']).to eq('301177')
          end
        end
      end
    end

    context 'without a valid file number' do
      it 'returns a bad request error' do
        VCR.use_cassette('bgs/people_service/no_person_data') do
          VCR.use_cassette('debts/get_letters_empty_ssn', VCR::MATCH_EVERYTHING) do
            expect(Sentry).to receive(:set_tags).once.with(external_service: described_class.to_s.underscore)
            expect(Sentry).to receive(:set_extras).once.with(
              url: Settings.dmc.url,
              message: 'the server responded with status 400',
              body: { 'message' => 'Bad request' }
            )

            expect { described_class.new(user_no_ssn).get_debts }.to raise_error(
              Common::Exceptions::BackendServiceException
            ) do |e|
              expect(e.message).to match(/DMC400/)
            end

            # Verify metrics were recorded
            expect(StatsD).to have_received(:increment).with('api.dmc.init_cached_debts.fired')
            expect(StatsD).to have_received(:increment).with(
              'api.dmc.fetch_debts_from_dmc.fail',
              tags: ['error:CommonClientErrorsClientError', 'status:400']
            )
            expect(StatsD).to have_received(:increment).with('api.dmc.fetch_debts_from_dmc.total')
          end
        end
      end
    end

    context 'empty DMC response' do
      it 'handles an empty payload' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_empty_response', VCR::MATCH_EVERYTHING) do
            Timecop.freeze(Time.utc(2024, 8, 4, 3, 0, 0)) do
              expect(Rails.cache).to receive(:write).once.with(
                "debts_data_#{user.uuid}",
                [],
                hash_including(expires_in: be_within(1.second).of(2.hours))
              )

              res = described_class.new(user).get_debts
              expect(JSON.parse(res.to_json)['debts']).to eq([])
            end
          end
        end
      end
    end

    context 'with count_only parameter' do
      it 'returns only count when count_only is true' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_count_only', VCR::MATCH_EVERYTHING) do
            # When requesting just the count
            response = described_class.new(user).get_debts(count_only: true)

            expect(response).to be_a(Hash)
            expect(response).to have_key('debtsCount')
            expect(response['debtsCount']).to be > 0

            expect(StatsD).to have_received(:increment).with('api.dmc.fetch_debts_from_dmc.total')
            expect(StatsD).to have_received(:increment).with('api.dmc.get_debts_count.success')
          end
        end
      end

      it 'returns full debt data when count_only is false' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters', VCR::MATCH_EVERYTHING) do
            response = described_class.new(user).get_debts(count_only: false)

            expect(response).to have_key(:has_dependent_debts)
            expect(response).to have_key(:debts)
            expect(response[:debts]).to be_an(Array)
            expect(response[:debts]).not_to be_empty

            expect(StatsD).to have_received(:increment).with('api.dmc.fetch_debts_from_dmc.total')
            expect(StatsD).to have_received(:increment).with('api.dmc.get_debts.success')
          end
        end
      end
    end
  end
end
