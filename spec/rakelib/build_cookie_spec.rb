# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'rake build_cookie', type: :task do
  let(:user) { create(:user) }
  let(:session) { Session.create(uuid: user.uuid, token: 'abracadabra') }

  before(:all) do
    Rake.application.rake_require '../rakelib/build_cookie'
    Rake::Task.define_task(:environment)
  end

  describe 'task: headers' do
    it 'raises an error when no token is provided' do
      expect { invoke_task 'build_cookie:headers' }.to raise_error('No token provided')
    end

    it 'raises an error when token doesnt match session' do
      expect { invoke_task 'build_cookie:headers[blah]' }.to raise_error('No session available for token')
    end

    it 'runs without errors' do
      stub_const("RAKE_VERIFY_HEADERS", true)
      invoke_task "build_cookie:headers[#{session.token}]"
    end
  end

  def invoke_task(task)
    Rake::Task['build_cookie:headers'].reenable
    Rake.application.invoke_task(task)
  end
end
