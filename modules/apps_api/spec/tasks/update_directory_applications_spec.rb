# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe AppsApi do
  before do
    Rails.application.load_tasks
  end

  let(:run_create_application_task) do
    Rake::Task['apps_api:create_applications'].invoke
  end

  it 'runs without error' do
    expect { run_create_application_task }.not_to raise_error
  end
end
