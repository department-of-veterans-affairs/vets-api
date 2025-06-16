# frozen_string_literal: true

# Ensure this specific test runs in test environment
ENV['RAILS_ENV'] = 'test'

require 'rails_helper'
require 'rake'

RSpec.describe 'decision_reviews rake tasks', type: :task do
  before do
    Rake.application.rake_require '../rakelib/decision_reviews_update_in_progress_sc'
    Rake::Task.define_task(:environment)
  end

  let(:new_return_url) { '/supporting-evidence/private-medical-records-authorization' }
  let(:cache_file) { Rails.root.join('tmp', 'test_supplemental_claims_update_data.json') }

  # Use around block for atomic cleanup that prevents race conditions
  around do |example|
    # Clean before test
    FileUtils.rm_f(cache_file)
    FileUtils.mkdir_p(Rails.root.join('tmp')) # Ensure tmp dir exists

    # Run the test
    example.run

    # Clean after test (this always runs, even if test fails)
    FileUtils.rm_f(cache_file)
  end

  describe 'dry_run_supplemental_claims_update' do
    let(:task) { Rake::Task['decision_reviews:dry_run_supplemental_claims_update'] }

    before do
      task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'when there are forms that need updates' do
      let!(:eligible_form_needs_update) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/old-url' })
      end

      let!(:eligible_form_already_correct) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: new_return_url })
      end

      let!(:ineligible_form) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: false,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/some-url' })
      end

      it 'identifies forms that need updates and caches the data' do
        expect { task.invoke }.to output(a_string_including('DRY RUN SUMMARY')).to_stdout

        # Check that cache file was created
        expect(File.exist?(cache_file)).to be true

        # Parse cache data
        cache_data = JSON.parse(File.read(cache_file))

        expect(cache_data['total_forms_scanned']).to eq(3)
        expect(cache_data['new_return_url']).to eq(new_return_url)
        expect(cache_data['updates_needed'].size).to eq(1)

        # Check the cached update data
        update_data = cache_data['updates_needed'].first
        expect(update_data['id']).to eq(eligible_form_needs_update.id)
        expect(update_data['original_return_url']).to eq('/old-url')
      end
    end

    context 'when no forms need updates' do
      let!(:eligible_form_already_correct) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: new_return_url })
      end

      it 'reports that no updates are needed' do
        expect { task.invoke }.to output(
          a_string_including('All eligible forms already have the correct return_url!')
        ).to_stdout

        expect(File.exist?(cache_file)).to be false
      end
    end

    context 'when there are no forms at all' do
      it 'handles empty dataset gracefully' do
        expect { task.invoke }.to output(
          a_string_including('Total forms analyzed: 0')
        ).to_stdout

        expect(File.exist?(cache_file)).to be false
      end
    end
  end

  describe 'update_in_progress_sc_from_cache' do
    let(:task) { Rake::Task['decision_reviews:update_in_progress_sc_from_cache'] }

    before do
      task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'when cache file does not exist' do
      it 'exits with error message' do
        expect { task.invoke }.to output(
          a_string_including('No cached data found')
        ).to_stdout.and raise_error(SystemExit)
      end
    end

    context 'when cache file exists with valid data' do
      let!(:form_to_update) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/old-url' })
      end

      before do
        # Ensure directory exists and create cache file
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        cache_data = {
          generated_at: Time.current.iso8601,
          new_return_url:,
          total_forms_scanned: 1,
          updates_needed: [
            {
              id: form_to_update.id,
              original_return_url: '/old-url'
            }
          ]
        }
        File.write(cache_file, JSON.pretty_generate(cache_data))
      end

      it 'updates the forms using cached data' do
        expect { task.invoke }.to output(
          a_string_including('Successfully updated: 1')
        ).to_stdout

        form_to_update.reload
        expect(form_to_update.metadata['return_url']).to eq(new_return_url)
      end

      it 'preserves cache file for potential rollback' do
        task.invoke
        expect(File.exist?(cache_file)).to be true
      end
    end

    context 'when form is no longer eligible' do
      let!(:form_changed) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: false,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/old-url' })
      end

      before do
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        cache_data = {
          generated_at: Time.current.iso8601,
          new_return_url:,
          total_forms_scanned: 1,
          updates_needed: [
            {
              id: form_changed.id,
              original_return_url: '/old-url'
            }
          ]
        }
        File.write(cache_file, JSON.pretty_generate(cache_data))
      end

      it 'skips the form and reports error' do
        expect { task.invoke }.to output(
          a_string_including('no longer eligible')
        ).to_stdout

        form_changed.reload
        expect(form_changed.metadata['return_url']).to eq('/old-url')
      end
    end
  end

  describe 'rollback_in_progress_sc_update' do
    let(:task) { Rake::Task['decision_reviews:rollback_in_progress_sc_update'] }

    before do
      task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'when cache file does not exist' do
      it 'exits with error message' do
        expect { task.invoke }.to output(
          a_string_including('No rollback data found')
        ).to_stdout.and raise_error(SystemExit)
      end
    end

    context 'when cache file exists and user confirms rollback' do
      let!(:form_to_rollback) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: new_return_url }) # Currently has new URL
      end

      before do
        # Create cache file with rollback data
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        cache_data = {
          generated_at: Time.current.iso8601,
          new_return_url:,
          total_forms_scanned: 1,
          updates_needed: [
            {
              id: form_to_rollback.id,
              original_return_url: '/original-url'
            }
          ]
        }
        File.write(cache_file, JSON.pretty_generate(cache_data))

        # Mock user confirmation
        allow($stdin).to receive(:gets).and_return("y\n")
      end

      it 'rolls back forms to original return_url values' do
        expect { task.invoke }.to output(
          a_string_including('Successfully rolled back: 1')
        ).to_stdout

        form_to_rollback.reload
        expect(form_to_rollback.metadata['return_url']).to eq('/original-url')
      end
    end

    context 'when user cancels rollback' do
      before do
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        cache_data = {
          generated_at: Time.current.iso8601,
          new_return_url:,
          total_forms_scanned: 1,
          updates_needed: [{ id: 1, original_return_url: '/old-url' }]
        }
        File.write(cache_file, JSON.pretty_generate(cache_data))

        allow($stdin).to receive(:gets).and_return("n\n")
      end

      it 'cancels the rollback' do
        expect { task.invoke }.to output(
          a_string_including('Rollback cancelled')
        ).to_stdout.and raise_error(SystemExit)
      end
    end
  end

  describe 'edge cases and error handling' do
    let(:dry_run_task) { Rake::Task['decision_reviews:dry_run_supplemental_claims_update'] }
    let(:update_task) { Rake::Task['decision_reviews:update_in_progress_sc_from_cache'] }

    before do
      dry_run_task.reenable
      update_task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'when forms have empty metadata' do
      let!(:form_with_empty_metadata) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: {})
      end

      it 'handles empty metadata gracefully' do
        expect { dry_run_task.invoke }.to output(
          a_string_including('Need return_url update: 1')
        ).to_stdout

        cache_data = JSON.parse(File.read(cache_file))
        update_item = cache_data['updates_needed'].first
        expect(update_item['original_return_url']).to be_nil
      end
    end

    context 'when form data structure is unexpected' do
      let!(:form_with_weird_data) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: { unexpected: 'structure', some: 'data' }, # Valid but unexpected
               metadata: { return_url: '/some-url' })
      end

      it 'handles unexpected form data structure' do
        expect { dry_run_task.invoke }.to output(
          a_string_including('Total forms analyzed: 1')
        ).to_stdout

        # Should not crash, and no cache file should be created since no updates needed
        expect(File.exist?(cache_file)).to be false
      end
    end

    context 'when database errors occur during update' do
      let!(:valid_form) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/old-url' })
      end

      before do
        # Run dry run first
        dry_run_task.invoke

        # Mock a save failure
        allow_any_instance_of(InProgressForm).to receive(:save).and_return(false)
        allow_any_instance_of(InProgressForm).to receive(:errors).and_return(
          double(full_messages: ['Validation failed'])
        )
      end

      it 'handles save failures gracefully' do
        expect { update_task.invoke }.to output(
          a_string_including('Failed to save form ID')
        ).to_stdout

        # Cache file should be preserved due to errors
        expect(File.exist?(cache_file)).to be true
      end
    end
  end

  describe 'cache file management' do
    let(:dry_run_task) { Rake::Task['decision_reviews:dry_run_supplemental_claims_update'] }

    before do
      dry_run_task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'when cache file already exists' do
      before do
        # Create an existing cache file
        FileUtils.mkdir_p(Rails.root.join('tmp'))
        existing_data = {
          generated_at: 1.hour.ago.iso8601,
          new_return_url: '/old-cache-url',
          total_forms_scanned: 999,
          updates_needed: [{ id: 999, original_return_url: '/fake' }]
        }
        File.write(cache_file, JSON.pretty_generate(existing_data))
      end

      let!(:test_form) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: { return_url: '/test-url' })
      end

      it 'overwrites existing cache file' do
        dry_run_task.invoke

        cache_data = JSON.parse(File.read(cache_file))
        expect(cache_data['new_return_url']).to eq(new_return_url)
        expect(cache_data['total_forms_scanned']).to eq(1)
        expect(cache_data['updates_needed'].size).to eq(1)
        expect(cache_data['updates_needed'].first['id']).to eq(test_form.id)
      end
    end
  end

  # Simplified batch processing tests
  describe 'batch processing behavior' do
    let(:dry_run_task) { Rake::Task['decision_reviews:dry_run_supplemental_claims_update'] }
    let(:update_task) { Rake::Task['decision_reviews:update_in_progress_sc_from_cache'] }

    before do
      dry_run_task.reenable
      update_task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    context 'with small batch for testing' do
      before do
        # Create just a few forms for faster testing
        5.times do |i|
          create(:in_progress_form,
                 form_id: '20-0995',
                 form_data: {
                   privacy_agreement_accepted: true,
                   'view:has_private_evidence': true
                 },
                 metadata: { return_url: "/batch-url-#{i}" })
        end
      end

      it 'processes all forms correctly' do
        expect { dry_run_task.invoke }.to output(
          a_string_including('Total forms analyzed: 5')
        ).to_stdout

        cache_data = JSON.parse(File.read(cache_file))
        expect(cache_data['updates_needed'].size).to eq(5)

        expect { update_task.invoke }.to output(
          a_string_including('Successfully updated: 5')
        ).to_stdout
      end
    end
  end

  # Simplified integration test
  describe 'basic workflow integration' do
    let(:dry_run_task) { Rake::Task['decision_reviews:dry_run_supplemental_claims_update'] }
    let!(:test_form) do
      create(:in_progress_form,
             form_id: '20-0995',
             form_data: {
               privacy_agreement_accepted: true,
               'view:has_private_evidence': true
             },
             metadata: { return_url: '/original-url' })
    end
    let(:update_task) { Rake::Task['decision_reviews:update_in_progress_sc_from_cache'] }
    let(:rollback_task) { Rake::Task['decision_reviews:rollback_in_progress_sc_update'] }

    before do
      dry_run_task.reenable
      update_task.reenable
      rollback_task.reenable
      # Stub cache file paths so tests use test-specific file
      allow(Rails.root).to receive(:join).with('tmp').and_return(Rails.root.join('tmp'))
      allow(Rails.root).to receive(:join).with('tmp', 'supplemental_claims_update_data.json').and_return(cache_file)
    end

    it 'completes dry run -> update -> rollback workflow' do
      # Dry run
      expect { dry_run_task.invoke }.to output(
        a_string_including('DRY RUN SUMMARY')
      ).to_stdout
      expect(File.exist?(cache_file)).to be true

      # Update
      expect { update_task.invoke }.to output(
        a_string_including('Successfully updated: 1')
      ).to_stdout

      test_form.reload
      expect(test_form.metadata['return_url']).to eq(new_return_url)

      # Rollback
      allow($stdin).to receive(:gets).and_return("y\n")
      expect { rollback_task.invoke }.to output(
        a_string_including('Successfully rolled back: 1')
      ).to_stdout

      test_form.reload
      expect(test_form.metadata['return_url']).to eq('/original-url')
    end
  end
end
