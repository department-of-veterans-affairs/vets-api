# frozen_string_literal: true

require 'rails_helper'
require 'okta/directory_service.rb'
require 'okta/service'

RSpec.describe Okta::DirectoryService do
  let(:subject) { described_class.new }

  describe '#initialize' do
    it 'creates the service correctly' do
      expect(subject.okta_service).to be_instance_of(Okta::Service)
    end
  end

  describe '#scopes' do
    it 'directs to #handle_health_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('health').and_return('boop')
      expect(subject.scopes('health')).to be('boop')
    end
    it 'directs to #handle_nonhealth_server as expected' do
      allow_any_instance_of(Okta::DirectoryService).to receive(:scopes).with('verification').and_return('beep')
      expect(subject.scopes('verification')).to be('beep')
    end
  end
end
