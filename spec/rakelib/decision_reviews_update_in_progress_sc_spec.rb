# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'decision_reviews:update_in_progress_sc', type: :task do
  let(:new_return_url) { '/supporting-evidence/private-medical-records-authorization' }
  let(:task) { Rake::Task['decision_reviews:update_in_progress_sc'] }

  before do
    Rake.application.rake_require '../rakelib/decision_reviews_update_in_progress_sc'
    Rake::Task.define_task(:environment)
    Rake::Task['decision_reviews:update_in_progress_sc'].reenable
  end

  after do
    InProgressForm.delete_all
  end

  describe 'when processing in-progress forms' do
    context 'with forms that should be updated' do
      let!(:form_should_update_one) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: {
                 return_url: '/option-claims'
               },
               id: 1001)
      end

      let!(:form_should_update_two) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: {
                 return_url: '/some-other-page'
               },
               id: 1011)
      end

      let!(:form_no_return_url) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: {},
               id: 1012)
      end

      let!(:form_already_correct) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               },
               metadata: {
                 return_url: new_return_url
               },
               id: 1013)
      end

      it 'updates forms that meet criteria and need URL change' do
        expect { task.invoke }.to output(/Updated return_url for user #{form_should_update_one.user_uuid}/).to_stdout

        form_should_update_one.reload
        metadata = form_should_update_one.metadata
        expect(metadata['return_url']).to eq(new_return_url)
      end

      it 'updates forms with different existing return_url' do
        expect { task.invoke }.to output(/Updated return_url for user #{form_should_update_two.user_uuid}/).to_stdout

        form_should_update_two.reload
        metadata = form_should_update_two.metadata
        expect(metadata['return_url']).to eq(new_return_url)
      end

      it 'updates forms with no existing return_url' do
        expect { task.invoke }.to output(/Updated return_url for user #{form_no_return_url.user_uuid}/).to_stdout

        form_no_return_url.reload
        metadata = form_no_return_url.metadata
        expect(metadata['return_url']).to eq(new_return_url)
      end

      it 'skips forms that already have correct return_url' do
        original_metadata = form_already_correct.metadata

        task.invoke

        form_already_correct.reload
        expect(form_already_correct.metadata).to eq(original_metadata)
      end

      it 'shows correct summary counts' do
        output = capture_stdout { task.invoke }

        expect(output).to include('Forms updated: 4')
        expect(output).to include('Total forms processed: 4')
      end
    end

    context 'with forms that should be skipped' do
      let!(:privacy_false) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: false,
                 'view:has_private_evidence': true
               })
      end

      let!(:evidence_false) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': false
               })
      end

      let!(:both_false) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: false,
                 'view:has_private_evidence': false
               })
      end

      let!(:privacy_missing) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 'view:has_private_evidence': true
               })
      end

      let!(:evidence_missing) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true
               })
      end

      let!(:both_missing) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 form5103Acknowledged: true
               })
      end

      let!(:privacy_null) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: nil,
                 'view:has_private_evidence': true
               })
      end

      let!(:evidence_null) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': nil
               })
      end

      let!(:privacy_string) do
        create(:in_progress_form,
               form_id: '20-0995',
               form_data: {
                 privacy_agreement_accepted: 'true',
                 'view:has_private_evidence': true
               })
      end

      it 'skips all forms that do not meet criteria' do
        output = capture_stdout { task.invoke }

        expect(output).to include('Forms updated: 0')
        expect(output).to include('Total forms processed: 9')
        expect(output).to include('Forms skipped: 9')
      end

      it 'logs reason for skipping each form' do
        output = capture_stdout { task.invoke }

        expect(output).to include("Skipped user #{privacy_false.user_uuid}")
        expect(output).to include('privacy_agreement_accepted: false')
        expect(output).to include("Skipped user #{evidence_false.user_uuid}")
        expect(output).to include('view:has_private_evidence: false')
      end

      it 'does not modify any skipped forms' do
        original_metadata = [
          privacy_false.metadata,
          evidence_false.metadata,
          both_false.metadata,
          privacy_missing.metadata,
          evidence_missing.metadata,
          both_missing.metadata,
          privacy_null.metadata,
          evidence_null.metadata,
          privacy_string.metadata
        ]

        task.invoke

        current_metadata = [
          privacy_false.reload.metadata,
          evidence_false.reload.metadata,
          both_false.reload.metadata,
          privacy_missing.reload.metadata,
          evidence_missing.reload.metadata,
          both_missing.reload.metadata,
          privacy_null.reload.metadata,
          evidence_null.reload.metadata,
          privacy_string.reload.metadata
        ]

        expect(current_metadata).to eq(original_metadata)
      end
    end

    context 'with error conditions' do
      let!(:corrupted_metadata) do
        form = create(:in_progress_form,
                      form_id: '20-0995',
                      form_data: {
                        privacy_agreement_accepted: true,
                        'view:has_private_evidence': true
                      },
                      metadata: '')
        # Manually corrupt the metadata to simulate invalid JSON
        form
      end

      it 'handles JSON parsing errors gracefully' do
        output = capture_stdout { task.invoke }

        expect(output).to include("Unexpected error processing user #{corrupted_metadata.user_uuid}")
        expect(output).to include('Forms failed to save: 1')
        expect(output).to include('Failed InProgressForm IDs:')
        expect(output).to include(corrupted_metadata.id.to_s)
      end

      it 'provides helpful debugging information' do
        output = capture_stdout { task.invoke }

        expect(output).to include('Failed InProgressForm IDs:')
        expect(output).to include('To investigate failures, you can query:')
        expect(output).to include('InProgressForm.where(id: [')
      end
    end

    context 'with different form IDs' do
      let!(:wrong_form_id) do
        create(:in_progress_form,
               form_id: '21-526EZ',
               form_data: {
                 privacy_agreement_accepted: true,
                 'view:has_private_evidence': true
               })
      end

      it 'only processes forms with correct form_id' do
        output = capture_stdout { task.invoke }

        expect(output).to include('Total forms processed: 0')
        expect(wrong_form_id.reload.metadata).not_to include(new_return_url)
      end
    end

    context 'with batch processing' do
      before do
        # Create more than 500 forms to test batching
        600.times do |i|
          create(:in_progress_form,
                 form_id: '20-0995',
                 form_data: {
                   privacy_agreement_accepted: true,
                   'view:has_private_evidence': true
                 },
                 metadata: {
                   return_url: '/option-claims'
                 },
                 id: 2000 + i)
        end
      end

      it 'processes forms in batches and shows progress' do
        output = capture_stdout { task.invoke }

        expect(output).to include('Processing batch of 500 forms')
        expect(output).to include('Processing batch of 100 forms')
        expect(output).to include('Progress: 500/')
        expect(output).to include('Progress: 600/')
        expect(output).to include('Forms updated: 600')
      end
    end
  end

  describe 'decision_reviews:preview_update_in_progress_sc' do
    let(:preview_task) { Rake::Task['decision_reviews:preview_update_in_progress_sc'] }
    let(:task) { Rake::Task['decision_reviews:preview_update_in_progress_sc'] }

    before do
      Rake.application.rake_require '../rakelib/decision_reviews_update_in_progress_sc'
      Rake::Task.define_task(:environment)
      Rake::Task['decision_reviews:preview_update_in_progress_sc'].reenable
    end

    let!(:eligible_form) do
      create(:in_progress_form,
             form_id: '20-0995',
             form_data: {
               privacy_agreement_accepted: true,
               'view:has_private_evidence': true
             },
             metadata: {
               return_url: '/option-claims'
             })
    end

    let!(:ineligible_form) do
      create(:in_progress_form,
             form_id: '20-0995',
             form_data: {
               privacy_agreement_accepted: false,
               'view:has_private_evidence': true
             })
    end

    it 'shows preview without making changes' do
      output = capture_stdout { preview_task.invoke }

      expect(output).to include('DRY RUN: Previewing')
      expect(output).to include("Would update user #{eligible_form.user_uuid}")
      expect(output).to include('Eligible for update: 1')
      expect(output).to include('Would skip: 1')

      # Verify no actual changes were made
      eligible_form.reload
      metadata = eligible_form.metadata
      expect(metadata['return_url']).to eq('/option-claims')
    end
  end

  private

  def capture_stdout
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end
end
