# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::VbmsUploader, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  describe 'uploading a file to vbms' do
    let(:power_of_attorney) { create(:power_of_attorney) }

    it 'responds properly when there is a 500 error' do
      VCR.use_cassette('vbms/document_upload_500') do
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.vbms_upload_failure_count).to eq(1)
      end
    end

    it 'creates a second job if there is a failure' do
      VCR.use_cassette('vbms/document_upload_500') do
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(1)
      end
    end

    it 'does not create an new job if had 5 failures' do
      VCR.use_cassette('vbms/document_upload_500') do
        power_of_attorney.update(vbms_upload_failure_count: 4)
        expect do
          subject.new.perform(power_of_attorney.id)
        end.to change(subject.jobs, :size).by(0)
      end
    end

    it 'updates the power of attorney record when successful response' do
      VCR.use_cassette('vbms/document_upload_success') do
        subject.new.perform(power_of_attorney.id)
        power_of_attorney.reload
        expect(power_of_attorney.status).to eq('uploaded')
        expect(power_of_attorney.vbms_document_series_ref_id).to eq('{52300B69-1D6E-43B2-8BEB-67A7C55346A2}')
        expect(power_of_attorney.vbms_new_document_version_ref_id).to eq('{A57EF6CC-2236-467A-BA4F-1FA1EFD4B374}')
      end
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    poa.save
    poa
  end
end
