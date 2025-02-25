# frozen_string_literal: true

require 'rails_helper'
require 'va_profile/prefill/military_information'

describe VAProfile::Prefill::MilitaryInformation do
  subject { described_class.new(user) }

  let(:user) { build(:user, :loa3) }

  context 'military personnel service' do
    describe '#sw_asia_combat' do
      it 'returns if veteran was deployed to sw asia during gulf war' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200',
                         match_requests_on: %i[method body]) do
          expect(subject.sw_asia_combat).to be(false)
        end
      end

      it 'returns false if there is no deployment location' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
          expect(subject.sw_asia_combat).to be(false)
        end
      end
    end

    describe '#discharge_type' do
      it 'returns discharge type' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200',
                         match_requests_on: %i[method body]) do
          expect(subject.discharge_type).to eq('general')
        end
      end

      it 'with an unknown character_of_discharge_code it returns nil' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes') do
          expect(subject.discharge_type).to be_nil
        end
      end
    end

    describe '#last_discharge_date' do
      it 'returns last end date' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          expect(subject.last_discharge_date).to eq('2018-10-31')
        end
      end
    end

    describe '#last_entry_date' do
      it 'returns last begin date' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          expect(subject.last_entry_date).to eq('2012-03-02')
        end
      end
    end

    describe '#post_nov111998_combat' do
      context 'with no post 1998 deployment' do
        it 'returns false' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                           match_requests_on: %i[method body]) do
            expect(subject.post_nov111998_combat).to be(false)
          end
        end
      end

      context 'with a post 1998 deployment' do
        it 'returns true' do
          VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200',
                           match_requests_on: %i[method body]) do
            expect(subject.post_nov111998_combat).to be(true)
          end
        end
      end
    end

    describe '#deployments' do
      it 'returns deployments' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200',
                         match_requests_on: %i[method body]) do
          expect(
            subject.deployments.pluck('deployment_end_date')
          ).to eq(['2005-10-25'])
        end
      end
    end

    describe '#hca_last_service_branch' do
      context 'with an unacceptable service branch code' do
        it 'returns other' do
          # rubocop:disable RSpec/SubjectStub
          allow(subject).to receive(:military_service_episodes).and_return(
            [OpenStruct.new(branch_of_service_code: 'DVN')]
          )
          # rubocop:enable RSpec/SubjectStub
          expect(subject.hca_last_service_branch).to eq('other')
        end
      end

      it 'returns hca formatted last service branch' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          expect(subject.hca_last_service_branch).to eq('army')
        end
      end
    end

    describe '#service_episodes_by_date' do
      context 'with a nil end date' do
        it 'returns sorted military_service_episodes' do
          # rubocop:disable RSpec/SubjectStub
          allow(subject).to receive(:military_service_episodes).and_return(
            [
              OpenStruct.new(end_date: '2018-10-31'),
              OpenStruct.new(end_date: nil)
            ]
          )
          # rubocop:enable RSpec/SubjectStub
          service_episodes_by_date = subject.service_episodes_by_date
          expect(service_episodes_by_date.map(&:end_date)).to eq([nil, '2018-10-31'])
        end
      end

      it 'returns sorted military_service_episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          service_episodes_by_date = subject.service_episodes_by_date
          expect(service_episodes_by_date[0].end_date).to eq('2018-10-31')
          expect(service_episodes_by_date[2].end_date).to eq('2008-12-01')
        end
      end
    end

    describe '#military_service_episodes' do
      it 'returns military_service_episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          military_service_episodes = subject.military_service_episodes
          expect(military_service_episodes.size).to eq(3)
          expect(military_service_episodes[0].branch_of_service).to eq('Army')
        end
      end
    end

    describe '#last_service_branch' do
      it 'returns the most recent branch of military the veteran served under' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.last_service_branch
          expect(response).to eq('Army')
        end
      end
    end

    describe '#currently_active_duty' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.currently_active_duty

          expect(response).to be(false)
        end
      end
    end

    describe '#currently_active_duty_hash' do
      it 'returns false if veteran is not currently serving in active duty' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.currently_active_duty_hash

          expect(response).to eq({ yes: false })
        end
      end
    end

    describe '#service_periods' do
      it 'returns an array of service periods with service branch and date range' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_histories_200',
                         match_requests_on: %i[method body]) do
          response = subject.service_periods

          expect(response).to be_an(Array)

          service_period = response.first
          expect(service_period).to have_key(:service_branch)
          expect(service_period).to have_key(:date_range)

          date_range = service_period[:date_range]
          expect(date_range).to have_key(:from)
          expect(date_range).to have_key(:to)
        end
      end
    end

    describe '#guard_reserve_service_history' do
      it 'returns an array of guard and reserve service episode date ranges sorted by end_date' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          expected_response = [
            { from: '2000-04-07', to: '2009-01-23' },
            { from: '1989-08-20', to: '2002-07-01' },
            { from: '1989-08-20', to: '1992-08-23' }
          ]
          response = subject.guard_reserve_service_history

          expect(response).to be_an(Array)
          expect(response).to all(have_key(:from))
          expect(response).to all(have_key(:to))
          expect(response).to eq(expected_response)
        end
      end
    end

    describe '#guard_reserve_service_history nil end dates' do
      it 'returns an array of guard and reserve service episode date ranges sorted by end_date' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes_dup_end',
                         match_requests_on: %i[method body]) do
          expected_response = [
            { from: '2000-04-07', to: '' },
            { from: '1989-08-20', to: '2002-07-01' },
            { from: '1989-08-20', to: '1992-08-23' }
          ]

          response = subject.guard_reserve_service_history

          expect(response).to be_an(Array)
          expect(response).to eq(expected_response)
        end
      end
    end

    describe '#latest_guard_reserve_service_period' do
      it 'returns the most recently completed guard or reserve service period' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.latest_guard_reserve_service_period

          expect(response).to eq({ from: '2000-04-07', to: '2009-01-23' })
        end
      end
    end

    describe '#service_branches' do
      it 'returns a list of deduplicated service branch codes' do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.service_branches

          expect(response).to eq(%w[A F])
        end
      end

      it 'returns an empty array if there are no episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200_empty',
                         match_requests_on: %i[method body]) do
          response = subject.service_branches

          expect(response).to eq([])
        end
      end
    end

    describe '#tours_of_duty' do
      it "returns an array of hashes about the veteran's tours of duty" do
        VCR.use_cassette('va_profile/military_personnel/service_history_200_many_episodes',
                         match_requests_on: %i[method body]) do
          response = subject.tours_of_duty
          expected_response =
            [{
              service_branch: 'Army',
              date_range: { from: '1985-08-19', to: '1989-08-19' }
            },
             {
               service_branch: 'Army',
               date_range: { from: '1989-08-20', to: '1992-08-23' }
             },
             {
               service_branch: 'Army',
               date_range: { from: '1989-08-20', to: '2002-07-01' }
             },
             {
               service_branch: 'Air Force',
               date_range: { from: '2000-04-07', to: '2009-01-23' }
             },
             {
               service_branch: 'Army',
               date_range: { from: '2002-07-02', to: '2014-08-31' }
             }]

          expect(response).to eq(expected_response)
        end
      end

      it 'returns an empty array if there are no episodes' do
        VCR.use_cassette('va_profile/military_personnel/post_read_service_history_200_empty',
                         match_requests_on: %i[method body]) do
          response = subject.tours_of_duty

          expect(response).to eq([])
        end
      end
    end
  end
end
