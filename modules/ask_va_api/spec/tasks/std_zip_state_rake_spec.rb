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

  describe 'development seeding' do
    let(:seed_data) do
      require Rails.root.join('modules', 'ask_va_api', 'lib', 'ask_va_api', 'seed', 'std_zip_state_records')
      AskVAApi::Seed::StdZipStateRecords
    end

    before { stub_environment('development') }

    it 'creates the expected states and zip codes' do
      old_reset = ENV.fetch('RESET', nil)
      ENV['RESET'] = 'true'

      expected_state_codes = seed_data::STATES.map { |s| s[:postal_name] }
      expected_zip_codes   = seed_data::ZIPCODES.map { |z| z[:zip_code] }

      expect do
        task.invoke
      end.to change { StdState.where(postal_name: expected_state_codes).count }
        .to(seed_data::STATES.size)
        .and change { StdZipcode.where(zip_code: expected_zip_codes).count }
        .to(seed_data::ZIPCODES.size)
    ensure
      ENV['RESET'] = old_reset
      task.reenable
    end
  end
end
