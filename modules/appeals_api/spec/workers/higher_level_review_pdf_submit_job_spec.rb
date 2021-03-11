# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) { fixture_to_s 'valid_200996_headers.json' }
  let(:higher_level_review) { create_higher_level_review }
  let(:client_stub) { instance_double('CentralMail::Service') }
  let(:faraday_response) { instance_double('Faraday::Response') }
  let(:valid_doc) { fixture_to_s 'valid_200996.json' }

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
    described_class.new.perform(higher_level_review.id)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(higher_level_review.id)
    updated = AppealsApi::HigherLevelReview.find(higher_level_review.id)
    expect(updated.status).to eq('submitted')
  end

  it 'sets error status for upstream server error' do
    allow(CentralMail::Service).to receive(:new) { client_stub }
    allow(faraday_response).to receive(:status).and_return(422)
    allow(faraday_response).to receive(:body).and_return('')
    allow(faraday_response).to receive(:success?).and_return(false)
    capture_body = nil
    expect(client_stub).to receive(:upload) { |arg|
      capture_body = arg
      faraday_response
    }
    described_class.new.perform(higher_level_review.id)
    expect(capture_body).to be_a(Hash)
    expect(capture_body).to have_key('metadata')
    expect(capture_body).to have_key('document')
    metadata = JSON.parse(capture_body['metadata'])
    expect(metadata['uuid']).to eq(higher_level_review.id)
    updated = AppealsApi::HigherLevelReview.find(higher_level_review.id)
    expect(updated.status).to eq('error')
    expect(updated.code).to eq('DOC104')
  end

  context 'with a downstream error' do
    before do
      allow(CentralMail::Service).to receive(:new) { client_stub }
      allow(faraday_response).to receive(:status).and_return(500)
      allow(faraday_response).to receive(:body).and_return('')
      allow(faraday_response).to receive(:success?).and_return(false)
    end

    it 'queues another job to retry the request' do
      expect(client_stub).to receive(:upload) { |_arg| faraday_response }
      Timecop.freeze(Time.zone.now)
      described_class.new.perform(higher_level_review.id)
      expect(described_class.jobs.last['at']).to eq(30.minutes.from_now.to_f)
      Timecop.return
    end
  end

  context 'an error throws' do
    it 'updates the HLR status to reflect the error' do
      submit_job_worker = described_class.new
      allow(submit_job_worker).to receive(:upload_to_central_mail).and_raise(RuntimeError, 'runtime error!')

      expect do
        submit_job_worker.perform(higher_level_review.id)
      end.to raise_error(RuntimeError, 'runtime error!')

      higher_level_review.reload
      expect(higher_level_review.status).to eq('error')
    end
  end

  private

  def create_higher_level_review
    higher_level_review = create(:higher_level_review)
    higher_level_review.auth_headers = JSON.parse(auth_headers)
    higher_level_review.save
    higher_level_review
  end
end
