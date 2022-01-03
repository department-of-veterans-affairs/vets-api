# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'rake claims:export', type: :task do
  subject(:task) { tasks[task_name] }

  let(:task_name) { self.class.top_level_description.sub(/\Arake /, '') }
  let(:tasks) { Rake::Task }

  before do
    load File.expand_path('../../../lib/tasks/claims_tasks.rake', __dir__)
    Rake::Task.define_task(:environment)
  end

  it 'preloads the Rails environment' do
    expect(task.prerequisites).to include 'environment'
  end

  it 'runs gracefully with no subscribers' do
    expect { task.execute }.not_to raise_error
  end

  context 'when no matching claims are found' do
    it 'logs to stdout' do
      expect { task.execute }.to output(/.*id,evss_id,has_flashes,has_special_issues.*/).to_stdout
    end
  end

  context 'when matching claims are found' do
    let!(:claim) { create(:auto_established_claim, evss_id: 'evss-id-here') }

    it 'logs to stdout' do
      lines = [
        'id,evss_id,has_flashes,has_special_issues',
        "(#{claim.id}),(#{claim.evss_id}),(true|false),(true|false)"
      ]
      expect { task.execute }.to output(/.*#{lines.join('.*')}.*/m).to_stdout
    end
  end
end
