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

describe 'rake claims:fix_failed_claims', type: :task do
  subject(:task) { tasks[task_name] }

  let(:task_name) { 'claims:fix_failed_claims' }
  let(:tasks) { Rake::Task }

  before do
    load File.expand_path('../../../lib/tasks/claims_tasks.rake', __dir__)
    Rake::Task.define_task(:environment)
  end

  after do
    task.reenable
  end

  it 'preloads the Rails environment' do
    expect(task.prerequisites).to include 'environment'
  end

  context 'single claim with supporting documents' do
    let(:claim) do
      create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
    end

    before do
      # Mock ClaimEstablisher to update claim status
      allow(ClaimsApi::ClaimEstablisher).to receive(:perform_async) do |claim_id|
        claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
        claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      end

      # Mock ClaimUploader
      allow(ClaimsApi::ClaimUploader).to receive(:perform_async)

      # Stub sleep to speed up tests
      allow_any_instance_of(Kernel).to receive(:sleep)
    end

    it 'reestablishes the claim' do
      args = Rake::TaskArguments.new([:claim_ids], [claim.id])
      task.execute(args)

      expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_async).with(claim.id).once
    end

    it 'uploads the 526EZ PDF' do
      args = Rake::TaskArguments.new([:claim_ids], [claim.id])
      task.execute(args)

      expect(ClaimsApi::ClaimUploader).to have_received(:perform_async).with(claim.id, 'claim').once
    end

    it 'uploads each supporting document' do
      args = Rake::TaskArguments.new([:claim_ids], [claim.id])
      task.execute(args)

      expect(ClaimsApi::ClaimUploader).to have_received(:perform_async).with(
        claim.supporting_documents.first.id, 'document'
      ).once
    end

    it 'completes successfully' do
      args = Rake::TaskArguments.new([:claim_ids], [claim.id])
      expect { task.execute(args) }.not_to raise_error
    end
  end

  context 'multiple claims' do
    let(:claim1) do
      create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
    end
    let(:claim2) do
      create(
        :auto_established_claim_with_supporting_documents,
        supporting_documents_count: 3,
        status: ClaimsApi::AutoEstablishedClaim::ERRORED
      )
    end

    before do
      # Mock ClaimEstablisher to update claim status
      allow(ClaimsApi::ClaimEstablisher).to receive(:perform_async) do |claim_id|
        claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
        claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      end

      # Mock ClaimUploader
      allow(ClaimsApi::ClaimUploader).to receive(:perform_async)

      # Stub sleep to speed up tests
      allow_any_instance_of(Kernel).to receive(:sleep)
    end

    it 'reestablishes all claims' do
      args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
      task.execute(args)

      expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_async).with(claim1.id).once
      expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_async).with(claim2.id).once
    end

    it 'completes successfully' do
      args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
      expect { task.execute(args) }.not_to raise_error
    end

    it 'runs the ClaimUploader for all claims and their supporting documents' do
      args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
      task.execute(args)

      expect(ClaimsApi::ClaimUploader).to have_received(:perform_async).with(claim1.id, 'claim').once
      expect(ClaimsApi::ClaimUploader).to have_received(:perform_async).with(claim2.id, 'claim').once

      claim1.supporting_documents.each do |sup|
        expect(
          ClaimsApi::ClaimUploader
        ).to have_received(:perform_async).with(sup.id, 'document').once
      end

      claim2.supporting_documents.each do |sup|
        expect(
          ClaimsApi::ClaimUploader
        ).to have_received(:perform_async).with(sup.id, 'document').once
      end

      # expect the claim uploader to have been called the correct number of times
      # (1 for each claim + 1 for each supporting document)
      total_claims = 2
      total_supporting_documents = claim1.supporting_documents.count + claim2.supporting_documents.count
      expect(
        ClaimsApi::ClaimUploader
      ).to have_received(:perform_async).exactly(total_claims + total_supporting_documents).times
    end
  end
end
