# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Disability Claims', type: :request do
  let(:headers) do
    { 'X-VA-SSN': '796-04-3735',
      'X-VA-First-Name': 'WESLEY',
      'X-VA-Last-Name': 'FORD',
      'X-Consumer-Username': 'TestConsumer',
      'X-VA-Birth-Date': '1986-05-06T00:00:00+00:00',
      'X-VA-Gender': 'M' }
  end
  let(:scopes) { %w[system/claim.write] }

  before do
    stub_poa_verification
    stub_mpi
    Timecop.freeze(Time.zone.now)
  end

  after do
    Timecop.return
  end

  describe '#526' do
    context 'submit' do
    end

    context 'validate' do
    end

    context 'attachments' do
    end
  end
end
