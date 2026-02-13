# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'vre:claims_batch_log', type: :task do
  before(:all) do
    Rake.application.rake_require '../rakelib/prod/vre_claims_batch_log'
    Rake::Task.define_task(:environment)
  end

  let(:task) { Rake::Task['vre:claims_batch_log'] }

  around do |example|
    original_env = ENV.to_hash
    ENV['START_DATE'] = '2026-01-14'
    ENV['END_DATE'] = '2026-01-24'
    example.run
  ensure
    ENV.replace(original_env)
  end

  before do
    task.reenable
  end

  describe 'claim filtering' do
    let!(:in_range_claim) do
      create(:veteran_readiness_employment_claim, created_at: Time.zone.parse('2026-01-15'), form_id: '28-1900')
    end
    let!(:out_of_range_before) do
      create(:veteran_readiness_employment_claim, created_at: Time.zone.parse('2026-01-13'), form_id: '28-1900')
    end
    let!(:out_of_range_after) do
      create(:veteran_readiness_employment_claim, created_at: Time.zone.parse('2026-01-25'), form_id: '28-1900')
    end
    let!(:wrong_form_id) do
      create(:veteran_readiness_employment_claim, created_at: Time.zone.parse('2026-01-15'), form_id: '28-1901')
    end

    it 'enqueues jobs only for claims within date range and correct form_id' do
      expect(VREVBMSDocumentUploadLogJob).to receive(:perform_async).with(in_range_claim.id).once
      expect(VREVBMSDocumentUploadLogJob).not_to receive(:perform_async).with(out_of_range_before.id)
      expect(VREVBMSDocumentUploadLogJob).not_to receive(:perform_async).with(out_of_range_after.id)
      expect(VREVBMSDocumentUploadLogJob).not_to receive(:perform_async).with(wrong_form_id.id)

      task.invoke
    end
  end

  describe 'with no claims found' do
    it 'exits early when no claims match criteria' do
      expect(VREVBMSDocumentUploadLogJob).not_to receive(:perform_async)
      expect { task.invoke }.to output(/No claims found. Exiting./).to_stdout
    end
  end

  describe 'with custom date range' do
    around do |example|
      original_env = ENV.to_hash
      ENV['START_DATE'] = '2025-12-01'
      ENV['END_DATE'] = '2025-12-31'
      example.run
    ensure
      ENV.replace(original_env)
    end

    it 'uses custom date parameters when provided' do
      claim = create(:veteran_readiness_employment_claim, created_at: Time.zone.parse('2025-12-15'), form_id: '28-1900')
      expect(VREVBMSDocumentUploadLogJob).to receive(:perform_async).with(claim.id)

      task.invoke
    end
  end
end
