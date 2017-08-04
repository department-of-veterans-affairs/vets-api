# frozen_string_literal: true
require 'rails_helper'

RSpec.describe HCA::ServiceJob, type: :job do
  let(:user) { create(:user) }
  let(:health_care_application) { create(:health_care_application) }
  let(:form) { { foo: true } }
  let(:result) do
    {
      formSubmissionId: 123,
      timestamp: '2017-08-03 22:02:18 -0400'
    }
  end

  describe '#perform' do
    it 'should call the service and save the results' do
    end
  end
end
