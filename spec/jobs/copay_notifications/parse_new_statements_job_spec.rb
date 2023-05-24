# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CopayNotifications::ParseNewStatementsJob, type: :worker do
  before do
    Sidekiq::Worker.clear_all
  end

  describe '#perform' do
    let(:statements_json_byte) { Base64.encode64(File.read('spec/fixtures/medical_copays/new_statements.json')) }

    it 'parses and creates individual new statement jobs' do
      job = described_class.new
      expect { job.perform(statements_json_byte) }
        .to change { CopayNotifications::NewStatementNotificationJob.jobs.size }
        .from(0)
        .to(2)
    end

    context 'duplicate identifiers' do
      let(:statements_json_byte) do
        Base64.encode64(File.read('spec/fixtures/medical_copays/duplicate_new_statements.json'))
      end

      it 'only creates a single job for duplicate identifiers' do
        job = described_class.new
        expect { job.perform(statements_json_byte) }
          .to change { CopayNotifications::NewStatementNotificationJob.jobs.size }
          .from(0)
          .to(1)
      end
    end
  end
end
