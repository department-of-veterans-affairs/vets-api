# frozen_string_literal: true

require 'rails_helper'
require 'support/form1010cg_helpers/build_claim_data_for'

RSpec.describe Form1010cg::DeliverAttachmentsToCARMAJob do
  include Form1010cgHelpers

  it 'inherits Sidekiq::Worker' do
    expect(described_class.ancestors).to include(Sidekiq::Worker)
  end

  describe '#perform' do
    describe 'unit' do
    end

    describe 'integration' do
      let(:vcr_options) do
        {
          record: :none,
          allow_unused_http_interactions: false,
          match_requests_on: %i[method host body]
        }
      end

      context 'without POA attachment' do
        let(:poa_attachment_id) { 'cdbaedd7-e268-49ed-b714-ec543fbb1fb8' }
        let(:carma_case_id)     { '4ycecujyo5k9rmlCAK' }
        let(:attachment)        { build(:form1010cg_attachment, guid: poa_attachment_id) }
        let(:form_data)         { build_claim_data { |d| d['poaAttachmentId'] = poa_attachment_id }.to_json }
        let(:claim)             { build(:caregivers_assistance_claim, form: form_data) }
        let(:submission)        { build(:form1010cg_submission, claim_guid: claim.guid, carma_case_id: carma_case_id) }

        def create_attachment_upload!
          VCR.use_cassette("s3/object/put/#{poa_attachment_id}/doctors-note_jpg", vcr_options) do
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

        it 'sends the PDF of claim to CARMA' do
        end
      end

      context 'with POA attachment' do
      end
    end
  end
end
