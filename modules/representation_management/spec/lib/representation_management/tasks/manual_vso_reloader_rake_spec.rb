# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'representation_management:reload_representation_management_vso' do
  before(:all) do
    Rake.application = Rake::Application.new

    Rake.application.rake_require(
      'tasks/manual_vso_reloader',
      [RepresentationManagement::Engine.root.join('lib')]
    )

    Rake::Task.define_task(:environment)
  end

  after(:all) do
    Rake.application = nil
  end

  let(:task_name) { 'representation_management:reload_representation_management_vso' }
  let(:task) { Rake::Task[task_name] }

  before do
    task.reenable
  end

  it 'runs VSOReloader synchronously' do
    reloader = instance_double(RepresentationManagement::VSOReloader)

    expect(RepresentationManagement::VSOReloader).to receive(:new).and_return(reloader)
    expect(reloader).to receive(:perform)

    task.invoke
  end

  it 'logs and re-raises when VSOReloader errors' do
    reloader = instance_double(RepresentationManagement::VSOReloader)

    expect(RepresentationManagement::VSOReloader).to receive(:new).and_return(reloader)
    expect(reloader).to receive(:perform).and_raise(StandardError, 'boom')

    expect(Rails.logger).to receive(:error).with(/VSOReloader failed: StandardError: boom/)
    expect { task.invoke }.to raise_error(StandardError, 'boom')
  end
end
