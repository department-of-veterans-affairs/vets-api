# frozen_string_literal: true

require 'rails_helper'
require 'webmock/rspec'

RSpec.describe LoadAverageDaysForClaimCompletionJob, type: :job do
  describe '#perform' do
    describe 'should load data into the table' do
      it 'queries the appropriate web page' do
        stub_request(:get, 'https://www.va.gov/disability/after-you-file-claim/')
          .to_return(status: 200, body: '>100.0 days</')

        LoadAverageDaysForClaimCompletionJob.new.perform
        assert_requested :get, 'https://www.va.gov/disability/after-you-file-claim/', times: 1
      end

      it 'inserts the record into the database' do
        stub_request(:get, 'https://www.va.gov/disability/after-you-file-claim/')
          .to_return(status: 200, body: '>101.0 days</')

        LoadAverageDaysForClaimCompletionJob.new.perform
        rtn = AverageDaysForClaimCompletion.order('created_at DESC').first

        expect(rtn.present?).to be(true)
        expect(rtn.average_days).to eq(101.0)
      end

      it 'does not perform an insert if the record fails to parse' do
        stub_request(:get, 'https://www.va.gov/disability/after-you-file-claim/')
          .to_return(status: 200, body: 'no match days')

        LoadAverageDaysForClaimCompletionJob.new.perform
        rtn = AverageDaysForClaimCompletion.order('created_at DESC').first

        expect(rtn.present?).to be(false)
      end

      it 'does not perform an insert if the web failure' do
        stub_request(:get, 'https://www.va.gov/disability/after-you-file-claim/')
          .to_return(status: 404, body: 'error back')

        LoadAverageDaysForClaimCompletionJob.new.perform
        rtn = AverageDaysForClaimCompletion.order('created_at DESC').first

        expect(rtn.present?).to be(false)
      end
    end
  end
end
