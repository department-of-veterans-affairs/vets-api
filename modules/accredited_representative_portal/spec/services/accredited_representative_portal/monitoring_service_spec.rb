# frozen_string_literal: true

require 'rails_helper'
require 'statsd-instrument'

module AccreditedRepresentativePortal
  module Monitoring
    RSpec.describe Service do
      let(:logger) { instance_double(Logging::Monitor) }
      let(:service) { described_class.new(user_context: user_context, default_tags: default_tags) }
      let(:user_context) { instance_double('UserContext', uuid: '123') } # rubocop:disable RSpec/VerifiedDoubleReference
      let(:default_tags) { ['env:test'] }

      before do
        allow(::Logging::Monitor).to receive(:new).and_return(logger)
        allow(logger).to receive(:track)
        allow(StatsD).to receive(:measure)
      end

      describe '#track_request' do
        it 'logs a request with default message and tags' do
          service.track_request

          expect(logger).to have_received(:track).with(
            :info, 'Request recorded', Monitoring::Metric::POA,
            tags: contain_exactly('env:test', 'service:accredited-representative-portal', 'user:123')
          )
        end

        it 'logs a request with custom message and tags' do
          service.track_request(message: 'Custom Message', tags: [Monitoring::Tag::Operation::CREATE])

          expect(logger).to have_received(:track).with(
            :info, 'Custom Message', Monitoring::Metric::POA,
            tags: contain_exactly('env:test', 'service:accredited-representative-portal',
                                  'user:123', 'operation:create')
          )
        end
      end

      describe '#track_error' do
        it 'logs an ActiveRecord validation error with correct tag' do
          error = ActiveRecord::RecordInvalid.new
          service.track_error(message: 'Validation failed', error: error)

          expect(logger).to have_received(:track).with(
            :error, 'Validation failed', Monitoring::Metric::POA,
            tags: contain_exactly(
              'env:test', 'service:accredited-representative-portal', 'user:123',
              Monitoring::Tag::Level::ERROR,
              Monitoring::Tag::Error::VALIDATION
            )
          )
        end

        it 'logs a timeout error with correct tag' do
          error = Timeout::Error.new
          service.track_error(message: 'Timeout occurred', error: error)

          expect(logger).to have_received(:track).with(
            :error, 'Timeout occurred', AccreditedRepresentativePortal::Monitoring::Metric::POA,
            tags: contain_exactly(
              'env:test', 'service:accredited-representative-portal', 'user:123',
              Monitoring::Tag::Level::ERROR,
              Monitoring::Tag::Error::TIMEOUT
            )
          )
        end

        it 'logs a 404 Not Found error with correct tag' do
          error = ActiveRecord::RecordNotFound.new
          service.track_error(message: 'Resource not found', error: error)

          expect(logger).to have_received(:track).with(
            :error, 'Resource not found', Monitoring::Metric::POA,
            tags: contain_exactly(
              'env:test', 'service:accredited-representative-portal', 'user:123',
              Monitoring::Tag::Level::ERROR,
              Monitoring::Tag::Error::NOT_FOUND
            )
          )
        end

        it 'logs an unexpected error as http_server error' do
          error = StandardError.new('Something went wrong')
          service.track_error(message: 'Unexpected error', error: error)

          expect(logger).to have_received(:track).with(
            :error, 'Unexpected error', Monitoring::Metric::POA,
            tags: contain_exactly(
              'env:test', 'service:accredited-representative-portal', 'user:123',
              Monitoring::Tag::Level::ERROR,
              Monitoring::Tag::Error::HTTP_SERVER
            )
          )
        end
      end
    end
  end
end
