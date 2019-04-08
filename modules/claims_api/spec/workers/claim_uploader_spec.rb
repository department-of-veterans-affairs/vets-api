# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::ClaimUploader, type: :job do
  before(:each) do
    Sidekiq::Worker.clear_all
  end

  subject { described_class }

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
  end

  let(:claim) do
    claim = create(:auto_established_claim)
    claim.auth_headers = auth_headers
    claim.save
    claim
  end

  let(:supporting_document) do
    supporting_document = create(:supporting_document)
    supporting_document.set_file_data!(
        Rack::Test::UploadedFile.new(
          "#{::Rails.root}/modules/claims_api/spec/fixtures/extras.pdf"
        ),
        'docType',
        'description'
      )
    supporting_document.save!
    supporting_document
  end

  it 'submits succesfully' do
    expect do
      subject.perform_async(supporting_document.id)
    end.to change(subject.jobs, :size).by(1)
  end

#   it 'sets a status of established on successful call' do
#     evss_service_stub = instance_double('EVSS::DisabilityCompensationForm::ServiceAllClaim')
#     allow(EVSS::DisabilityCompensationForm::ServiceAllClaim).to receive(:new) { evss_service_stub }
#     allow(evss_service_stub).to receive(:submit_form526) { OpenStruct.new(claim_id: 1337) }

#     subject.new.perform(claim.id)
#     claim.reload
#     expect(claim.evss_id).to eq(1337)
#     expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ESTABLISHED)
#   end

#   it 'sets the status of the claim to an error if it raises an error on EVSS' do
#     allow_any_instance_of(EVSS::DisabilityCompensationForm::ServiceAllClaim).to(
#       receive(:submit_form526).and_raise(Common::Exceptions::BackendServiceException)
#     )
#     expect { subject.new.perform(claim.id) }.to raise_error(Common::Exceptions::BackendServiceException)

#     claim.reload
#     expect(claim.evss_id).to eq(nil)
#     expect(claim.status).to eq(ClaimsApi::AutoEstablishedClaim::ERRORED)
#   end
end
