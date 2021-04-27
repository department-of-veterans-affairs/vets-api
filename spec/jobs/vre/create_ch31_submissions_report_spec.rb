# frozen_string_literal: true

require 'rails_helper'

RSpec.describe VRE::CreateCh31SubmissionsReport, type: :aws_helpers do
  subject do
    described_class.new
  end

  let(:time) { Time.zone.now }

  context 'with some sample claims', run_at: '2017-07-27 00:00:00 -0400' do
    let!(:vre_claim_1) do
      create(:veteran_readiness_employment_claim, updated_at: time.beginning_of_day)
    end

    let!(:vre_claim_2) do
      create(:veteran_readiness_employment_claim, updated_at: time.beginning_of_day)
    end

    before do
      subject.instance_variable_set(:@time, time)
    end

    describe '#create_csv_array' do
      it 'creates the right array' do
        submitted_claims = subject.get_claims_submitted_in_range
        expect(
          subject.create_csv_array(submitted_claims)
        ).to eq(
          csv_array: [['Count', 'Regional Office', 'PID', 'Date Application Received', 'Type of Form', 'Total'],
                      [1, '317', '600036503', '2017-07-27 00:00:00 UTC', vre_claim_1.form_id, 2],
                      [2, '317', '600036503', '2017-07-27 00:00:00 UTC', vre_claim_2.form_id, 2]]
        )
      end
    end

    describe '#perform' do
      after do
        File.delete(filename)
      end

      let(:filename) { "tmp/ch31_reports/#{time.to_date}.csv" }

      def perform
        stub_reports_s3(filename) do
          subject.perform
        end
      end

      it 'sends an email' do
        expect { perform }.to change {
          ActionMailer::Base.deliveries.count
        }.by(1)
      end

      it 'creates a csv file' do
        perform
        submitted_claims = subject.get_claims_submitted_in_range
        data = subject.create_csv_array(submitted_claims)
        csv_array = data[:csv_array]
        csv_string = CSV.generate do |csv|
          csv_array.each do |row|
            csv << row
          end
        end
        expect(File.read(filename)).to eq(csv_string)
      end
    end
  end
end
