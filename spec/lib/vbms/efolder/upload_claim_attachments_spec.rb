# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VBMS::Efolder::UploadClaimAttachments do
  let(:bc) { build(:burial_claim) } # plain burial claim with no attachments
  let(:pa) { build_stubbed(:pension_burial) } # persistent attachment
  let(:file) do
    fixture_file_upload(
      "#{::Rails.root}/spec/fixtures/pension/attachment.pdf", 'application/pdf'
    )
  end

  describe 'when processing a burial claim' do
    before do
      # save claim to get a created_at date and id
      pa.saved_claim.save
      allow_any_instance_of(SavedClaim).to receive('persistent_attachments').and_return(pa)
    end

    it 'finds and loads a claim with attachments' do
      uploader = described_class.new(pa.saved_claim)
      claim = uploader.instance_variable_get(:@claim)
      attachments = uploader.instance_variable_get(:@attachments)
      expect(claim.id).to be(pa.saved_claim.id)
      expect(claim.persistent_attachments.id).to be(pa.id)
    end

    it 'loads metadata from a claim' do
      uploader = described_class.new(pa.saved_claim)
      claim = uploader.instance_variable_get(:@claim)
      metadata = uploader.instance_variable_get(:@metadata)
      filenum = claim.open_struct_form.file_number || claim.open_struct_form.veteranSocialSecurityNumber
      receive_date = claim.created_at.in_time_zone('Central Time (US & Canada)')

      expect(metadata['file_number']).to eq(filenum)
      expect(metadata['source']).to eq('va.gov')
      expect(metadata['guid']).to eq(claim.guid)
      expect(metadata['doc_type']).to eq(claim.form_id)
      expect(metadata['first_name']).to eq(claim.open_struct_form.veteranFullName.first)
      expect(metadata['last_name']).to eq(claim.open_struct_form.veteranFullName.last)
      expect(metadata['zip_code']).to eq(claim.open_struct_form.claimantAddress.postalCode)
      expect(metadata['receive_date']).to eq(receive_date.strftime('%Y-%m-%d %H:%M:%S'))
    end
  end

  describe 'when processing a burial claim with no attachments' do
    it 'raises an error' do
      bc.save
      msg = "Claim #{bc.id} does not contain any supporting documents."
      expect(bc.persistent_attachments.count).to be(0)
      expect { described_class.new(bc)&.upload! }.to raise_error(ActiveRecord::RecordNotFound, msg)
    end
  end
end
