# frozen_string_literal: true

module Workflow
  class Runner
    QUEUE = 'tasker'
    STATS_KEY = 'api.workflow'
    attr_accessor :internal_options, :options, :current_step, :current_task
    include Sidekiq::Worker
    sidekiq_options queue: QUEUE

    def perform(task_index, data)
      data.deep_symbolize_keys!
      @current_step = task_index
      @options = data[:options]
      @internal_options = data[:internal] || {}
      @current_task = chain[task_index]
      Sidekiq::Logging.with_context("trace=#{@internal_options[:trace]}") do
        run_task_with_stats
        Runner.perform_async(next_step, metadata) if next_step
      end
    end

    # act like ActiveJob and wrap the true task class for logging purposes
    def self.perform_async(next_step, metadata)
      Sidekiq::Client.push(
        'class'   => self,
        'wrapped' => metadata[:internal][:chain][next_step][:mod],
        'queue'   => QUEUE,
        'args'    => [next_step, metadata]
      )
    end

    private

    def run_task_with_stats
      statsd_prefix = "#{STATS_KEY}.#{current_task[:mod].underscore}"

      begin
        StatsD.measure("#{statsd_prefix}.timing") { run_task }
        StatsD.increment("#{statsd_prefix}.success")
      rescue => e
        StatsD.increment("#{statsd_prefix}.failure")
        raise e
      end
    end

    def chain
      @internal_options[:chain]
    end

    def next_step
      @current_step + 1 if chain[@current_step + 1]
    end

    # Parameters for the next tasks to use.
    def metadata
      { internal: @internal_options, options: @options }
    end

    def run_task
      # Build the task class with the user and bookkeeping arguments
      task = current_task[:mod].constantize.new(@options, internal: @internal_options)
      runner = task.method(:run)
      if runner.arity.abs == 1
        runner.call(current_task[:args])
      else
        unless current_task[:args].empty?
          logger.error "#{current_task[:mod]} given unused argument(s) #{current_task[:args].to_json}"
        end
        runner.call
      end
      # update the user-provided and updated data for subsequent jobs
      @options = task.data
    end
  end
end
