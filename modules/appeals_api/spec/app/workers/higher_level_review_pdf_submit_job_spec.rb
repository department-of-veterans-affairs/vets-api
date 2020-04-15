# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:auth_headers) do
    File.read(
      Rails.root.join('modules', 'appeals_api', 'spec', 'fixtures', 'higher_level_review_create_headers.json')
    )
  end

  it 'calls out to the pdf constructor class' do
    allow_any_instance_of(AppealsApi::HigherLevelReviewPdfConstructor).to receive(:fill_pdf).and_return(true)
    higher_level_review = create_higher_level_review
    subject.new.perform(higher_level_review.id)
    higher_level_review.reload
    expect(higher_level_review.status).to eq('processing')
  end

  private

  def create_higher_level_review
    higher_level_review = create(:higher_level_review)
    higher_level_review.auth_headers = auth_headers
    higher_level_review.save
    higher_level_review
  end
end
