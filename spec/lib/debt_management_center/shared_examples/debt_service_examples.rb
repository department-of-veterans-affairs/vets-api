# frozen_string_literal: true

RSpec.shared_examples 'Flipper debts_cache_dmc_empty_response behavior' do |flipper_enabled|
  before do
    allow(Flipper).to receive(:enabled?).with(:debts_cache_dmc_empty_response).and_return(flipper_enabled)
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
            expect(StatsD).to receive(:increment).once.with('api.dmc.init_cached_debts.fired') if flipper_enabled

            expect(StatsD).to receive(:increment).once.with(
              flipper_enabled ? cached_error_metric : non_cached_error_metric, tags: [
                'error:CommonClientErrorsClientError', 'status:400'
              ]
            )
            expect(StatsD).to receive(:increment).once.with(
              flipper_enabled ? cached_total_metric : non_cached_total_metric
            )
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
          end
        end
      end
    end

    context 'empty DMC response' do
      it 'handles an empty payload' do
        VCR.use_cassette('bgs/people_service/person_data') do
          VCR.use_cassette('debts/get_letters_empty_response', VCR::MATCH_EVERYTHING) do
            Timecop.freeze(Time.utc(2024, 8, 4, 3, 0, 0)) do
              expected_expires_in = 2.hours

              if flipper_enabled
                expect(Rails.cache).to receive(:write).once.with(
                  "debts_data_#{user.uuid}",
                  [],
                  hash_including(expires_in: be_within(1.second).of(expected_expires_in))
                )
              end

              res = described_class.new(user).get_debts
              expect(JSON.parse(res.to_json)['debts']).to eq([])
            end
          end
        end
      end
    end
  end
end
