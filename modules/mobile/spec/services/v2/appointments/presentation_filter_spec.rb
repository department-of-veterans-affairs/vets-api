# frozen_string_literal: true

require 'rails_helper'

describe Mobile::V2::Appointments::PresentationFilter do
  let(:filterer) { described_class.new(include_pending: true) }
  let(:upcoming) { mock_appointment(id: 'upcoming', start: 1.day.from_now) }
  let(:past) { mock_appointment(id: 'past', start: 1.day.ago) }
  let(:cancelled) { mock_appointment(id: 'past', status: 'cancelled', start: 30.days.ago) }
  let(:request) do
    requested_periods = [{ start: 20.days.ago }]
    mock_appointment(id: 'request', status: 'proposed', created: 30.days.ago, requested_periods:)
  end

  def mock_appointment(id: nil, created: nil, status: nil, start: nil, requested_periods: nil)
    OpenStruct.new(
      id:,
      created: created&.to_s,
      status:,
      start: start&.to_s,
      requested_periods:
    )
  end

  before do
    Timecop.freeze
  end

  after do
    Timecop.return
  end

  describe '#user_facing?' do
    it 'returns true for upcoming appointment' do
      expect(filterer.user_facing?(upcoming)).to be true
    end

    it 'returns true for past appointments' do
      expect(filterer.user_facing?(past)).to be true
    end

    describe 'cancelled appointments' do
      it 'returns true for a cancelled appointment with a valid start time 30 days ago or after' do
        expect(filterer.user_facing?(cancelled)).to be true
      end

      it 'returns false if start time is more than 30 days ago' do
        cancelled[:start] = 31.days.ago
        expect(filterer.user_facing?(cancelled)).to be false
      end
    end

    describe 'appointment requests' do
      context 'when include_pending is true' do
        it 'returns true for appointment requests created during the requested date range' do
          expect(filterer.user_facing?(request)).to be true
        end

        it 'returns false if it was created more than 120 days ago' do
          request[:created] = 121.days.ago.to_s
          expect(filterer.user_facing?(request)).to be false
        end

        it 'returns false if it was created more than a day from now' do
          request[:created] = 2.days.from_now.to_s
          expect(filterer.user_facing?(request)).to be false
        end

        it 'returns false if it does not have requested_periods' do
          request[:requested_periods] = []
          expect(filterer.user_facing?(request)).to be false
        end
      end

      context 'when include_pending is false' do
        it 'returns false for appointment requests' do
          filterer_without_pending = described_class.new(include_pending: false)
          expect(filterer_without_pending.user_facing?(request)).to be false
        end
      end

      describe 'date validations', aggregate_errors: true do
        context 'for appointments' do
          it 'returns false but does not raise an error if start time is empty' do
            cancelled[:start] = nil
            expect(Rails.logger).not_to receive(:error)
            expect(filterer.user_facing?(cancelled)).to be false
          end

          it 'logs an error and returns false when appointment has an invalid start date' do
            upcoming[:start] = 'NOTADATE'
            expect(Rails.logger).to receive(:error).with('Invalid appointment time received: NOTADATE', 'invalid date')
            expect(filterer.user_facing?(upcoming)).to be false
          end
        end

        context 'for appointment requests' do
          it 'returns false but does not raise an error if created date is empty' do
            request[:created] = nil
            expect(Rails.logger).not_to receive(:error)
            expect(filterer.user_facing?(request)).to be false
          end

          it 'logs an error and returns false when appointment has an invalid created date' do
            request[:created] = 'NOTADATE'
            expect(Rails.logger).to receive(:error).with('Invalid appointment time received: NOTADATE', 'invalid date')
            expect(filterer.user_facing?(request)).to be false
          end
        end
      end
    end
  end
end
