# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mobile::V0::Adapters::Immunizations, type: :model do
  let(:adapter) { described_class.new }

  describe '#parse' do
    context 'group_name extraction' do
      before do
        allow(Flipper).to receive(:enabled?).with(:mhv_vaccine_lighthouse_name_logging).and_return(true)
      end

      context 'when coding has VACCINE GROUP: prefix at start with space' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '123',
                  vaccine_code: {
                    text: 'COVID-19 vaccine',
                    coding: [
                      { code: '207', display: 'COVID-19' },
                      { display: 'VACCINE GROUP: COVID-19' }
                    ]
                  },
                  occurrence_date_time: '2023-01-15'
                }
              }
            ]
          }
        end

        it 'extracts the group name correctly' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: [9]
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('COVID-19')
        end

        context 'when logging is disabled' do
          before do
            allow(Flipper).to receive(:enabled?).with(:mhv_vaccine_lighthouse_name_logging).and_return(false)
          end

          it 'does not log vaccine processing' do
            expect(Rails.logger).not_to receive(:info).with('Immunizations group_name processing', anything)

            result = adapter.parse(immunizations)
            expect(result.first.group_name).to eq('COVID-19')
          end
        end
      end

      context 'when coding has VACCINE GROUP: prefix without space after colon' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '124',
                  vaccine_code: {
                    text: 'Flu vaccine',
                    coding: [
                      { code: '141', display: 'INFLUENZA' },
                      { display: 'VACCINE GROUP:INFLUENZA' }
                    ]
                  },
                  occurrence_date_time: '2023-02-10'
                }
              }
            ]
          }
        end

        it 'extracts the group name correctly' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: [9]
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('INFLUENZA')
        end
      end

      context 'when coding has VACCINE GROUP: prefix with extra whitespace' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '125',
                  vaccine_code: {
                    text: 'Hepatitis vaccine',
                    coding: [
                      { code: '45', display: 'HEPATITIS B' },
                      { display: 'VACCINE GROUP:  HEPATITIS B  ' }
                    ]
                  },
                  occurrence_date_time: '2023-03-20'
                }
              }
            ]
          }
        end

        it 'trims whitespace and extracts group name correctly' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: [15]
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('HEPATITIS B')
        end
      end

      context 'when coding has VACCINE GROUP in the middle of text' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '126',
                  vaccine_code: {
                    text: 'Tetanus vaccine',
                    coding: [
                      { code: '115', display: 'TETANUS' },
                      { display: 'Some text VACCINE GROUP: TETANUS here' }
                    ]
                  },
                  occurrence_date_time: '2023-04-05'
                }
              }
            ]
          }
        end

        it 'does not match and falls back to coding index 1' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: []
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('Some text VACCINE GROUP: TETANUS here')
        end
      end

      context 'when no VACCINE GROUP: prefix exists' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '127',
                  vaccine_code: {
                    text: 'MMR vaccine',
                    coding: [
                      { code: '03', display: 'MMR' },
                      { display: 'MEASLES, MUMPS AND RUBELLA' }
                    ]
                  },
                  occurrence_date_time: '2023-05-12'
                }
              }
            ]
          }
        end

        it 'falls back to index 1 display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: []
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('MEASLES, MUMPS AND RUBELLA')
        end
      end

      context 'when only index 0 exists' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '128',
                  vaccine_code: {
                    text: 'Polio vaccine',
                    coding: [
                      { code: '10', display: 'POLIO' }
                    ]
                  },
                  occurrence_date_time: '2023-06-18'
                }
              }
            ]
          }
        end

        it 'falls back to index 0 display' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 1,
              vaccine_group_lengths: []
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('POLIO')
        end
      end

      context 'when VACCINE GROUP: prefix has only whitespace after' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '129',
                  vaccine_code: {
                    text: 'Unknown vaccine',
                    coding: [
                      { code: '999', display: 'UNKNOWN' },
                      { display: 'VACCINE GROUP:   ' }
                    ]
                  },
                  occurrence_date_time: '2023-07-22'
                }
              }
            ]
          }
        end

        it 'returns nil for empty group name after stripping' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: [3]
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to be_nil
        end
      end

      context 'when VACCINE GROUP: prefix has nothing after' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '129',
                  vaccine_code: {
                    text: 'Unknown vaccine',
                    coding: [
                      { code: '999', display: 'UNKNOWN' },
                      { display: 'VACCINE GROUP:' }
                    ]
                  },
                  occurrence_date_time: '2023-07-22'
                }
              }
            ]
          }
        end

        it 'returns nil for empty group name after stripping' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: [0]
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to be_nil
        end
      end

      context 'when coding display is nil' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '130',
                  vaccine_code: {
                    text: 'Varicella vaccine',
                    coding: [
                      { code: '21', display: nil },
                      { display: 'VARICELLA' }
                    ]
                  },
                  occurrence_date_time: '2023-08-30'
                }
              }
            ]
          }
        end

        it 'handles nil safely and falls back' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 2,
              vaccine_group_lengths: []
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to eq('VARICELLA')
        end
      end

      context 'when vaccine_codes[:coding] is nil' do
        let(:immunizations) do
          {
            entry: [
              {
                resource: {
                  id: '131',
                  vaccine_code: {
                    text: 'Test vaccine',
                    coding: nil
                  },
                  occurrence_date_time: '2023-09-15'
                }
              }
            ]
          }
        end

        it 'handles nil coding safely and returns nil' do
          expect(Rails.logger).to receive(:info).with(
            'Immunizations group_name processing',
            hash_including(
              coding_count: 0,
              vaccine_group_lengths: []
            )
          )

          result = adapter.parse(immunizations)
          expect(result.first.group_name).to be_nil
        end
      end
    end
  end
end
