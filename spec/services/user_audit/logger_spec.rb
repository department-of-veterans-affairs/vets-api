# frozen_string_literal: true

require 'rails_helper'

RSpec.describe UserAudit::Logger do
  shared_examples 'a status method' do
    let(:logger) { described_class.new }

    it 'logs with the correct level' do
      expect(logger).to receive(:info).with(status:)
      logger.send(status)
    end
  end

  describe '#initial' do
    let(:status) { 'initial' }

    it_behaves_like 'a status method'
  end

  describe '#success' do
    let(:status) { 'success' }

    it_behaves_like 'a status method'
  end

  describe '#error' do
    let(:status) { 'error' }

    it_behaves_like 'a status method'
  end
end
