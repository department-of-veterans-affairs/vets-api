# frozen_string_literal: true

require 'rails_helper'
require 'support/form1010cg_helpers/build_claim_data_for'

RSpec.describe Form1010cg::DeliverAttachmentsJob do
  include Form1010cgHelpers

  it 'inherits Sidekiq::Worker' do
    expect(described_class.ancestors).to include(Sidekiq::Worker)
  end

  describe '#perform' do
    describe 'integration' do
      let(:vcr_options) do
        {
          aws: {
            record: :none,
            allow_unused_http_interactions: false,
            match_requests_on: %i[method host]
          },
          carma: {
            record: :none,
            allow_unused_http_interactions: false,
            match_requests_on: %i[method host uri]
          }
        }
      end

      context 'with one docuemnt' do
        let(:carma_case_id) { 'aB935000000F3VnCAK' }
        let(:claim)         { build(:caregivers_assistance_claim) }
        let(:submission)    { build(:form1010cg_submission, claim_guid: claim.guid, carma_case_id: carma_case_id) }

        before do
          claim.save!
          submission.save!
        end

        after do
          SavedClaim::CaregiversAssistanceClaim.delete_all
          Form1010cg::Submission.delete_all
        end

        it 'sends the claim PDF to CARMA' do
          VCR.use_cassette('carma/auth/token/200', vcr_options[:carma]) do
            VCR.use_cassette('carma/attachments/upload/claim-pdf/201', vcr_options[:carma]) do
              subject.perform(claim.guid)
            end
          end

          expect(File.exist?("tmp/pdfs/10-10CG_#{claim.guid}.pdf")).to eq(false)
        end
      end

      context 'with two documents' do
        let(:carma_case_id)       { 'aB93500000017lDCAQ' }
        let(:poa_attachment_guid) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
        let(:attachment)          { build(:form1010cg_attachment, guid: poa_attachment_guid) }
        let(:form_data)           { build_claim_data { |d| d['poaAttachmentId'] = poa_attachment_guid }.to_json }
        let(:claim)               { build(:caregivers_assistance_claim, form: form_data) }
        let(:submission)          { build(:form1010cg_submission, claim_guid: claim.guid, carma_case_id: carma_case_id) } # rubocop:disable Layout/LineLength

        def create_attachment_upload!
          VCR.use_cassette("s3/object/put/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
            attachment.set_file_data!(
              Rack::Test::UploadedFile.new(
                Rails.root.join('spec', 'fixtures', 'files', 'doctors-note.jpg'),
                'image/jpg'
              )
            )
          end

          attachment.save!
        end

        before do
          create_attachment_upload!
          claim.save!
          submission.save!
        end

        after do
          Form1010cg::Attachment.delete_all
          SavedClaim::CaregiversAssistanceClaim.delete_all
          Form1010cg::Submission.delete_all
        end

        it 'sends the claim PDF and POA attachment to CARMA' do
          VCR.use_cassette("s3/object/get/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
            VCR.use_cassette('carma/auth/token/200', vcr_options[:carma]) do
              VCR.use_cassette('carma/attachments/upload/claim-pdf-and-poa/201', vcr_options[:carma]) do
                VCR.use_cassette("s3/object/delete/#{poa_attachment_guid}/doctors-note.jpg", vcr_options[:aws]) do
                  subject.perform(claim.guid)
                end
              end
            end
          end

          expect(File.exist?("tmp/#{poa_attachment_guid}_doctors-note.jpg")).to eq(false)
          expect(File.exist?("tmp/pdfs/10-10CG_#{claim.guid}.pdf")).to eq(false)
        end
      end
    end
  end
end
