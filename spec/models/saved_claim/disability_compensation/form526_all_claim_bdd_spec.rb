# frozen_string_literal: true

require 'rails_helper'
require 'disability_compensation/factories/api_provider_factory'

RSpec.describe SavedClaim::DisabilityCompensation::Form526AllClaim do
  let(:user) { build(:disabilities_compensation_user) }

  before do
    create(:in_progress_form, form_id: FormProfiles::VA526ez::FORM_ID, user_uuid: user.uuid)
    Timecop.freeze(Date.new(2020, 8, 1))
  end

  after { Timecop.return }

  describe '#to_submission_data' do
    context 'without a 4142 submission' do
      subject { described_class.from_hash(form_content) }

      let(:form_content) do
        JSON.parse(File.read('spec/support/disability_compensation_form/bdd_fe_submission.json'))
      end
      let(:submission_data) do
        JSON.parse(File.read('spec/support/disability_compensation_form/submissions/526_bdd.json'))
      end
    end
  end
end
