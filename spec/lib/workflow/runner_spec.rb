# frozen_string_literal: true

require 'rails_helper'
# rubocop:disable  Style/GlobalVars
class TestTaskA < Workflow::Task::Base
  def run
    $TaskCount += 1
    @data[:inc_mult] = 10
  end
end

class TestTaskB < Workflow::Task::Base
  def run(a)
    $TaskCount += a[:inc] * @data[:inc_mult]
  end
end

describe Workflow::Runner do
  let(:workflow) do
    Class.new(Workflow::Base) do |x|
      x.run TestTaskA, does: :notexist
      x.run TestTaskB, inc: 10
      x.run TestTaskB, inc: 100
    end
  end

  before do
    $TaskCount = 0
    workflow.new.start!(trace: 'rspec-hi')
  end

  context '#perform' do
    it 'runs the task at the provided index' do
      Workflow::Runner.perform_one
      expect($TaskCount).to eq(1)
    end

    it 'increments statsd success' do
      expect { Workflow::Runner.perform_one }.to trigger_statsd_increment('api.workflow.test_task_a.success')
    end

    it 'benchmarks the method and sends to statsd' do
      expect do
        Workflow::Runner.perform_one
      end.to trigger_statsd_measure(
        'api.workflow.test_task_a.timing',
        value: be_between(0, 10)
      )
    end

    context 'when run_task raises error' do
      before do
        allow_any_instance_of(Workflow::Runner).to receive(:run_task).and_raise('error')
      end

      it 'increments statds failure' do
        expect do
          expect { Workflow::Runner.perform_one }.to raise_error('error')
        end.to trigger_statsd_increment('api.workflow.test_task_a.failure')
      end
    end

    it 'queues the following task if there are more' do
      expect(Workflow::Runner).to receive(:perform_async).with(1, anything)
      Workflow::Runner.perform_one
    end

    it 'runs jobs until exhaustion' do
      expect(Workflow::Runner).to receive(:perform_async).and_call_original.twice
      Workflow::Runner.drain
      expect($TaskCount).to eq(1101)
    end

    it 'logs when a task is sent arguments that are not used' do
      expect(Sidekiq.logger). to receive(:error).with(/notexist/)
      Workflow::Runner.perform_one
    end

    it 'logs with the tracer' do
      expect(Sidekiq::Logging).to receive(:with_context).with('trace=rspec-hi').and_call_original.exactly(3).times
      Workflow::Runner.drain
    end
  end
end
# rubocop:enable  Style/GlobalVars
