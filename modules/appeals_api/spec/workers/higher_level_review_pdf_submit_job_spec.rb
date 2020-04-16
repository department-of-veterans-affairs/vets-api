# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  let(:upload) { FactoryBot.create(:higher_level_review) }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { File.read(Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'valid_200996.json')) }

    it 'uploads a valid payload' do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(200)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(true)
      capture_body = nil
      expect(client_stub).to receive(:upload) { |arg|
        capture_body = arg
        faraday_response
      }
      described_class.new.perform(upload.id)
      expect(capture_body).to be_a(Hash)
      expect(capture_body).to have_key('metadata')
      expect(capture_body).to have_key('document')
      metadata = JSON.parse(capture_body['metadata'])
      expect(metadata['uuid']).to eq(upload.guid)
      updated = AppealsApi::HigherLevelReview.find(upload.guid)
      expect(updated.status).to eq('received')
    end


  # it 'queues another job to retry the request' do
  #   expect(client_stub).to receive(:upload) { |_arg| faraday_response }
  #   Timecop.freeze(Time.zone.now)
  #   described_class.new.perform(upload.guid)
  #   expect(described_class.jobs.last['at']).to eq(30.minutes.from_now.to_f)
  #   Timecop.return
  # end
end

