# frozen_string_literal: true
 
require 'rails_helper'


RSpec.describe VBMS::Efolder::UploadClaimAttachments do
  subject { described_class }
  let(:bc) { build(:burial_claim)} # plain burial claim with no attachments
  let(:pa) { build_stubbed(:pension_burial) } # persistent attachment

  describe 'when processing a burial claim' do
    it 'finds and loads the claim and its attachments' do
      allow_any_instance_of(SavedClaim).to receive('persistent_attachments').and_return(pa)
      pa.saved_claim.save
      uploader = described_class.new(pa.saved_claim)
      claim = uploader.instance_variable_get(:@claim)
      attachments = uploader.instance_variable_get(:@attachments)
      
      expect(claim.id).to be(pa.saved_claim.id)
      expect(claim.persistent_attachments.id).to be(pa.id)
    end

    it 'loads metadata from a claim' do
      pa.saved_claim.save
      allow_any_instance_of(SavedClaim).to receive('persistent_attachments').and_return(pa)
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

    it 'raises an error if the claim does not contain any supporting documents to upload' do
      bc.save
      msg = "Claim #{bc.id} does not contain any supporting documents."
      expect(bc.persistent_attachments.count).to be(0)
      expect {described_class.new(bc)&.upload!}.to raise_error(ActiveRecord::RecordNotFound, msg)
    end
  end

  describe 'uploading attachments to vbms efolder' do
    it 'fetches an upload token' do

    end
    it 'uploads attachments' do

    end
    it 'handles vbms service outages' do

    end
    it 'cleans up after successful uploads' do

    end
    it 'retries uploading n times' do

    end
  end
end
