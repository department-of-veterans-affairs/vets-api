# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ClaimsApi::EvidenceWaiverBuilderJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  describe 'generating the filled and signed pdf' do
    it 'generates the pdf to match example' do
      target_veteran = OpenStruct.new({
                                        'first_name' => 'Tamera',
                                        'last_name' => 'Ellis'
                                      })

      expect(ClaimsApi::EvidenceWaiver).to receive(:new).and_call_original
      expect_any_instance_of(ClaimsApi::EvidenceWaiver).to receive(:construct).and_call_original
      subject.new.perform(target_veteran: target_veteran)
    end
  end
end
