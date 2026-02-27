# frozen_string_literal: true

require 'rails_helper'
require 'rake'

describe 'rake claims', type: :task do
  let(:tasks) { Rake::Task }

  before do
    Rake::Task.clear if Rake::Task.task_defined?('claims:export')
    Rake::Task.clear if Rake::Task.task_defined?('claims:fix_failed_claims')
    load File.expand_path('../../../lib/tasks/claims_tasks.rake', __dir__)
    Rake::Task.define_task(:environment)
  end

  describe 'claims:export' do
    subject(:task) { tasks[task_name] }

    let(:task_name) { 'claims:export' }

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

  describe 'claims:fix_failed_claims' do
    subject(:task) { tasks[task_name] }

    let(:task_name) { 'claims:fix_failed_claims' }

    before do
      # Mock ClaimEstablisher to update claim status
      allow(ClaimsApi::ClaimEstablisher).to receive(:perform_inline) do |claim_id|
        claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
        claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      end

      # Mock services
      allow(ClaimsApi::ClaimUploader).to receive(:perform_inline)
      allow(ClaimsApi::V1::Form526EstablishmentUpload).to receive(:perform_inline) do |claim_id|
        claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
        claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
      end
      allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_inline)
    end

    after do
      task.reenable
    end

    it 'preloads the Rails environment' do
      expect(task.prerequisites).to include 'environment'
    end

    # sad path edge cases
    context 'when claim is not found' do
      before do
        allow(Rails.logger).to receive(:warn)
      end

      it 'logs a warning and skips to the next claim' do
        args = Rake::TaskArguments.new([:claim_ids], ['non-existent-claim-id'])
        expect { task.execute(args) }.not_to raise_error
        expect(Rails.logger).to have_received(:warn).with('Could not find claim with id non-existent-claim-id').once
      end
    end

    context 'when the claim is in an errored state and fails to establish again' do
      let(:claim) do
        create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
      end

      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(false)
        claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))

        # Mock ClaimEstablisher to keep claim in errored state
        allow(ClaimsApi::ClaimEstablisher).to receive(:perform_inline) do |claim_id|
          claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
          claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ERRORED, evss_response: 'Some error')
        end
      end

      it 'logs the error and skips to the next claim' do
        allow(Rails.logger).to receive(:error)
        args = Rake::TaskArguments.new([:claim_ids], [claim.id])
        expect { task.execute(args) }.not_to raise_error
        expect(Rails.logger).to have_received(:error).with(
          /Error processing claim #{claim.id}/
        )
      end
    end

    context 'when the claim is in an errored state and does not have autoCestPDFGenerationDisabled in the form data' do
      let(:claim) do
        create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
      end

      before do
        allow(Rails.logger).to receive(:warn)
        claim.update!(form_data: (claim.form_data || {}).except('autoCestPDFGenerationDisabled'))
        args = Rake::TaskArguments.new([:claim_ids], [claim.id])
        task.execute(args)
      end

      it 'logs a warning and skips to the next claim' do
        expect(Rails.logger).to have_received(:warn).with(
          "Claim #{claim.id} is missing form_data or autoCestPDFGenerationDisabled flag, skipping PDF generation"
        ).once
      end
    end

    describe 'when the lighthouse_claims_api_v1_enable_FES feature flag is disabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(false)
      end

      describe 'when the claim has autoCestPDFGenerationDisabled set to true' do
        context 'single claim with supporting documents' do
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
          end

          before do
            claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
          end

          it 'reestablishes the claim' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_inline).with(claim.id).once
          end

          it 'uploads the 526EZ PDF' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(claim.id, 'claim').once
          end

          it 'uploads each supporting document' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(
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
            claim1.update!(form_data: (claim1.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
            claim2.update!(form_data: (claim2.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
          end

          it 'reestablishes all claims' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_inline).with(claim1.id).once
            expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_inline).with(claim2.id).once
          end

          it 'completes successfully' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            expect { task.execute(args) }.not_to raise_error
          end

          it 'runs the ClaimUploader for all claims and their supporting documents' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(claim1.id, 'claim').once
            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(claim2.id, 'claim').once

            claim1.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end

            claim2.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end

            # expect the claim uploader to have been called the correct number of times
            # (1 for each claim + 1 for each supporting document)
            total_claims = 2
            total_supporting_documents = claim1.supporting_documents.count + claim2.supporting_documents.count
            expect(
              ClaimsApi::ClaimUploader
            ).to have_received(:perform_inline).exactly(total_claims + total_supporting_documents).times
          end
        end
      end

      describe 'when the claim has autoCestPDFGenerationDisabled set to false' do
        let(:claim) do
          create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
        end

        before do
          claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
        end

        context 'for a single claim' do
          it 'reestablishes the claim' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimEstablisher).to have_received(:perform_inline).with(claim.id).once
          end

          it 'does NOT upload the 526EZ PDF' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).not_to have_received(:perform_inline).with(claim.id, 'claim')
          end

          it 'does NOT use the DisabilityCompensationPdfGenerator' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)
            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator)
              .not_to have_received(:perform_inline).with(claim.id, '')
          end

          it 'uploads each supporting document' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(
              claim.supporting_documents.first.id, 'document'
            ).once
          end

          it 'completes successfully' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            expect { task.execute(args) }.not_to raise_error
          end
        end
      end
    end

    describe 'when the lighthouse_claims_api_v1_enable_FES feature flag is enabled' do
      before do
        allow(Flipper).to receive(:enabled?).with(:lighthouse_claims_api_v1_enable_FES).and_return(true)
      end

      describe 'when the claim has autoCestPDFGenerationDisabled set to true' do
        context 'single claim with supporting documents' do
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
          end

          before do
            claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
          end

          it 'reestablishes the claim with Form526EstablishmentUpload' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(:perform_inline).with(claim.id).once
          end

          it 'uploads the 526EZ PDF' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).not_to have_received(:perform_inline).with(claim.id, 'claim')
          end

          it 'uploads each supporting document' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(
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
            claim1.update!(form_data: (claim1.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
            claim2.update!(form_data: (claim2.form_data || {}).merge('autoCestPDFGenerationDisabled' => true))
          end

          it 'reestablishes all claims' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(:perform_inline).with(claim1.id).once
            expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(:perform_inline).with(claim2.id).once
          end

          it 'completes successfully' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            expect { task.execute(args) }.not_to raise_error
          end

          it 'runs the ClaimUploader for all claims and their supporting documents' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(:perform_inline).with(claim1.id).once
            expect(ClaimsApi::V1::Form526EstablishmentUpload).to have_received(:perform_inline).with(claim2.id).once

            claim1.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end

            claim2.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end
          end
        end
      end

      describe 'when the claim has autoCestPDFGenerationDisabled set to false' do
        before do
          # mock the DisabilityCompensationPdfGenerator to update the claim status to established
          allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_inline) do |claim_id, _|
            claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
            claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
          end
          allow(MPI::Service).to receive(:new).and_return(
            double(find_profile_by_attributes: double(profile: double(given_names: %w[John Middle])))
          )
        end

        context 'for a single claim' do
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
          end

          before do
            claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
          end

          it 'reestablishes the claim' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to have_received(:perform_inline).with(
              claim.id,
              'M'
            ).once
            expect(ClaimsApi::ClaimEstablisher).not_to have_received(:perform_inline)
          end

          it 'does NOT upload the 526EZ PDF using Form526EstablishmentUpload' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::V1::Form526EstablishmentUpload).not_to have_received(:perform_inline).with(claim.id)
          end

          it 'uses the DisabilityCompensationPdfGenerator' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)
            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator)
              .to have_received(:perform_inline).with(claim.id, 'M')
          end

          it 'uploads each supporting document' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)

            expect(ClaimsApi::ClaimUploader).to have_received(:perform_inline).with(
              claim.supporting_documents.first.id, 'document'
            ).once
          end

          it 'completes successfully' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            expect { task.execute(args) }.not_to raise_error
          end
        end

        context 'for multiple claims' do
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
            claim1.update!(form_data: (claim1.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
            claim2.update!(form_data: (claim2.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
          end

          it 'reestablishes all claims with the DisabilityCompensationPdfGenerator' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to have_received(:perform_inline).with(
              claim1.id,
              'M'
            ).once
            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to have_received(:perform_inline).with(
              claim2.id,
              'M'
            ).once
            expect(ClaimsApi::ClaimEstablisher).not_to have_received(:perform_inline)
          end

          it 'does NOT upload the 526EZ PDF using Form526EstablishmentUpload' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            task.execute(args)

            expect(ClaimsApi::V1::Form526EstablishmentUpload).not_to have_received(:perform_inline).with(claim1.id)
            expect(ClaimsApi::V1::Form526EstablishmentUpload).not_to have_received(:perform_inline).with(claim2.id)
          end

          it 'completes successfully and uploads each supporting document' do
            args = Rake::TaskArguments.new([:claim_ids], ["#{claim1.id},#{claim2.id}"])
            expect { task.execute(args) }.not_to raise_error

            claim1.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end

            claim2.supporting_documents.each do |sup|
              expect(
                ClaimsApi::ClaimUploader
              ).to have_received(:perform_inline).with(sup.id, 'document').once
            end
          end
        end

        context 'when MPI does not have a middle name for the veteran' do
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
          end

          before do
            allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_inline) do |claim_id, _|
              claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
              claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
            end
            allow(MPI::Service).to receive(:new).and_return(
              double(find_profile_by_attributes: double(profile: double(given_names: %w[John])))
            )
            claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
          end

          it 'passes an empty string for the middle initial' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)
            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator)
              .to have_received(:perform_inline).with(claim.id, '')
          end
        end

        context 'when MPI has a middle name of "Null" for the veteran' do
          let(:claim) do
            create(:auto_established_claim_with_supporting_documents, status: ClaimsApi::AutoEstablishedClaim::ERRORED)
          end

          before do
            allow(ClaimsApi::V1::DisabilityCompensationPdfGenerator).to receive(:perform_inline) do |claim_id, _|
              claim_record = ClaimsApi::AutoEstablishedClaim.find(claim_id)
              claim_record.update!(status: ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
            end
            allow(MPI::Service).to receive(:new).and_return(
              double(find_profile_by_attributes: double(profile: double(given_names: %w[John Null])))
            )
            claim.update!(form_data: (claim.form_data || {}).merge('autoCestPDFGenerationDisabled' => false))
          end

          it 'passes an empty string for the middle initial' do
            args = Rake::TaskArguments.new([:claim_ids], [claim.id])
            task.execute(args)
            expect(ClaimsApi::V1::DisabilityCompensationPdfGenerator)
              .to have_received(:perform_inline).with(claim.id, '')
          end
        end
      end
    end
  end
end
