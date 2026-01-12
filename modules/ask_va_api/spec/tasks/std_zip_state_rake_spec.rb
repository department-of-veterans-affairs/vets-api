# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'ask_va_api:seed:std_zip_state', type: :task do
  subject(:task) { Rake::Task[task_name] }

  let(:task_name) { 'ask_va_api:seed:std_zip_state' }
  let(:task_path) { File.expand_path('../../lib/tasks/ask_va_api/seed/std_zip_state.rake', __dir__) }

  before do
    Rake.application = Rake::Application.new
    load task_path
    Rake::Task.define_task(:environment)
  end

  after do
    task.reenable
  end

  def stub_environment(env_name)
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new(env_name))
  end

  describe 'environment guard' do
    it 'aborts outside development' do
      stub_environment('test')

      expect { task.invoke }.to raise_error(SystemExit)
    end
  end
end
