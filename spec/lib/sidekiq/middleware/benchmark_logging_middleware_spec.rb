# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/benchmark_logging_worker'
require 'sidekiq/middleware/benchmark_logging_middleware'

class NormalTestWorker
  include Sidekiq::Worker

  def perform; end
end

class BenchmarkLoggingTestWorker < NormalTestWorker
  include Sidekiq::BenchmarkLoggingWorker
end

RSpec.describe Sidekiq::Middleware::BenchmarkLoggingMiddleware do
  let(:worker) { NormalTestWorker.new }
  let(:job) { {} }
  let(:queue) { 'default' }
  let(:middleware) { described_class.new }

  describe '#call' do
    context 'when the job does not include the benchmark logging module' do
      it 'does not log benchmark data' do
        expect(Rails.logger).not_to receive(:info)

        middleware.call(worker, job, queue) {}
      end
    end

    context 'when the job includes the benchmark logging module' do
      let(:worker) { BenchmarkLoggingTestWorker.new }
      let(:flag_name) { :sidekiq_benchmark_logging }

      it 'logs benchmark data' do
        expect(Rails.logger).to receive(:info) do |message|
          expect(message)
            .to eq('Sidekiq job BenchmarkLoggingTestWorker benchmark: {"real":0,"system":0,"total":0,"user":0}')
        end

        middleware.call(worker, job, queue) {}
      end
    end
  end
end
