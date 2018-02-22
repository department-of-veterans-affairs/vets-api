# frozen_string_literal: true

require 'rails_helper'

describe Workflow::Task::Base do
  let(:task) do
    described_class.new({ a: true, b: 'otest' }, internal: { c: 'itest' })
  end

  it 'stores provided options' do
    expect(task.data.keys).to contain_exactly(:a, :b)
    expect(task.data[:a]).to be(true)
    expect(task.data[:b]).to be('otest')
  end

  it 'stores internal options' do
    expect(task.internal.keys).to contain_exactly(:c)
    expect(task.internal[:c]).to be('itest')
  end

  it 'logs to sidekiq by default' do
    expect(Sidekiq.logger).to receive(:info).with(/sk logger/)
    task.logger.info('sk logger')
  end
end
