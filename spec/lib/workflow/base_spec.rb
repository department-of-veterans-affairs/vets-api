# frozen_string_literal: true

require 'rails_helper'

describe Workflow::Base do
  let(:defined_flow) { Class.new(Workflow::Base) }

  before do
    defined_flow.run :task_a
    defined_flow.run :task_b
  end

  context '#chain' do
    it 'stores tasks in order' do
      expect(defined_flow.chain.map { |c| c[:mod] }).to eq(%i[task_a task_b])
    end

    it 'stores provided arguments' do
      defined_flow.run :arg_task, x: 10, y: [1, 2, 3]
      task = defined_flow.chain.last
      expect(task[:args]).to eq(x: 10, y: [1, 2, 3])
    end
  end

  context '#start!' do
    let(:flow) { defined_flow.new(z: 12) }

    it 'queues the first job on the chain' do
      expect { flow.start! }.to change(Workflow::Runner.jobs, :size).by(1)
    end

    it 'passes book-keeping arguments to the job' do
      flow.start!(trace: 'testing')
      job = Workflow::Runner.jobs.first
      expect(job.dig('args', 0)).to eq(0)
      expect(job.dig('args', 1).keys).to contain_exactly('internal', 'options')
      expect(job.dig('args', 1, 'internal').keys).to contain_exactly('trace', 'chain')
      expect(job.dig('args', 1, 'internal', 'trace')).to eq('testing')
    end

    it 'gets a unique trace id if none is provided' do
      expect(SecureRandom).to receive(:uuid).and_return('1-2-3')
      flow.start!
      job = Workflow::Runner.jobs.first
      expect(job.dig('args', 1, 'internal', 'trace')).to eq('1-2-3')
    end
  end
end
