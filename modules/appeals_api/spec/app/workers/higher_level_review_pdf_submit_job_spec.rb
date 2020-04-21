# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe AppealsApi::HigherLevelReviewPdfSubmitJob, type: :job do
  before { Sidekiq::Worker.clear_all }

  it 'calls out to the pdf constructor class' do
    allow_any_instance_of(AppealsApi::HigherLevelReviewPdfConstructor).to receive(:fill_pdf).and_return(true)
    higher_level_review = create(:higher_level_review)
    described_class.new.perform(higher_level_review.id)
    higher_level_review.reload
    expect(higher_level_review.status).to eq('processing')
  end
end
