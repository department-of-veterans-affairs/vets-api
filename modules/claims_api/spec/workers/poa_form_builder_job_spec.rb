# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'

Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::PoaFormBuilderJob, type: :job do
  subject { described_class }

  before do
    Sidekiq::Worker.clear_all
  end

  let(:user) { FactoryBot.create(:user, :loa3) }
  let(:auth_headers) do
    headers = EVSS::DisabilityCompensationAuthHeaders.new(user).add_headers(EVSS::AuthHeaders.new(user).to_h)
    headers['va_eauth_pnid'] = '796104437'
    headers
  end

  describe 'generating the filled and signed pdf' do
    it 'generates the pdf to match example' do
      power_of_attorney = create_poa
      generated_pdf = subject.new.perform(power_of_attorney.id)
      puts generated_pdf
    end
  end

  private

  def create_poa
    poa = create(:power_of_attorney)
    poa.auth_headers = auth_headers
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    poa.form_data[:signatures] = {
      veteran: b64_image,
      representative: b64_image
    }
    poa.save
    poa
  end
end
