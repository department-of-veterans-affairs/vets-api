# frozen_string_literal: true

require 'rails_helper'
require 'lib/saved_claims_spec_helper'

RSpec.describe SavedClaim::EducationBenefits::VA0989 do
  let(:instance) { build(:va0989) }

  before do
    Sidekiq::Job.clear_all
  end

  it_behaves_like 'saved_claim'

  validate_inclusion(:form_id, '22-0989')

  describe 'after_submit' do
    let(:claim) { create(:va0989) }
    let(:user) { create(:user) }

    it 'queues up a submit claim job' do
      claim.after_submit(user)
      expect(EducationForm::SubmitEducationBenefitsClaimJob.jobs.size).to eq(1)
      expect(EducationForm::SubmitEducationBenefitsClaimJob.jobs[0]['args'].first).to eq(claim.id)
      expect(EducationForm::SubmitEducationBenefitsClaimJob.jobs[0]['args'].second).to eq(user.user_account.id)
    end
  end

  describe 'generate_benefits_intake_metadata' do
    it 'returns the right metadata' do
      expect(instance.generate_benefits_intake_metadata).to eq({
                                                                 'veteranFirstName' => 'John',
                                                                 'veteranLastName' => 'Doe',
                                                                 'fileNumber' => '123456789',
                                                                 'zipCode' => '98101',
                                                                 'source' => 'SavedClaim::EducationBenefits::VA0989',
                                                                 'docType' => '22-0989',
                                                                 'businessLine' => 'EDU'
                                                               })
    end
  end

  describe 'personalisation' do
    it 'returns the right values' do
      expect(instance.personalisation).to eq({
                                               first_name: 'John',
                                               last_name: 'Doe'
                                             })
    end
  end

  describe 'email' do
    it 'returns the right values' do
      expect(instance.email).to eq('john@example.com')
    end
  end
end
