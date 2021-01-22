# frozen_string_literal: true

require 'rails_helper'
require AppealsApi::Engine.root.join('spec', 'spec_helper.rb')

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  include FixtureHelpers

  subject { described_class }

  before { Sidekiq::Worker.clear_all }

  let(:auth_headers) { fixture_to_s 'valid_200996_headers.json' }
  let(:higher_level_review) { create_higher_level_review(:higher_level_review) }
  let(:extra_higher_level_review) { create_higher_level_review(:extra_higher_level_review) }
  let(:minimal_higher_level_review) { create_higher_level_review(:minimal_higher_level_review) }
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

  context 'pdf content verification' do
    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      generated_pdf = described_class.new.generate_pdf(higher_level_review.id)
      expected_pdf = fixture_filepath('expected_200996.pdf')
      expect(generated_pdf).to match_pdf expected_pdf
      File.delete(generated_pdf) if File.exist?(generated_pdf)
      Timecop.return
    end
  end

  context 'pdf extra content verification' do
    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      generated_pdf = described_class.new.generate_pdf(extra_higher_level_review.id)
      expected_pdf = fixture_filepath('expected_200996_extra.pdf')
      expect(generated_pdf).to match_pdf expected_pdf
      File.delete(generated_pdf) if File.exist?(generated_pdf)
      Timecop.return
    end
  end

  context 'pdf minimum content verification' do
    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      generated_pdf = described_class.new.generate_pdf(minimal_higher_level_review.id)
      expected_pdf = fixture_filepath('expected_200996_minimum.pdf')
      expect(generated_pdf).to match_pdf(expected_pdf)
      File.delete(generated_pdf) if File.exist?(generated_pdf)
      Timecop.return
    end
  end

  private

  def create_higher_level_review(type)
    higher_level_review = create(type)
    higher_level_review.auth_headers = JSON.parse(auth_headers)
    higher_level_review.save
    higher_level_review
  end
end
