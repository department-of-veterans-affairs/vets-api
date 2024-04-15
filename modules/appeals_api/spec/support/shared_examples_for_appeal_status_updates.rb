# frozen_string_literal: true

shared_examples 'an appeal model with updatable status' do |opts|
  let(:example_instance) { opts[:example_instance] }
  let(:instance_without_email) { opts[:instance_without_email] }

  describe '#update_status' do
    it 'handles the error statues with code and detail' do
      example_instance.update_status(status: 'error', code: 'code', detail: 'detail')

      expect(example_instance.status).to eq('error')
      expect(example_instance.code).to eq('code')
      expect(example_instance.detail).to eq('detail')
    end

    it 'clears a previous error status' do
      example_instance.update_status(status: 'error', code: 'code', detail: 'detail')
      example_instance.update_status(status: 'success')

      expect(example_instance.status).to eq('success')
      expect(example_instance.code).to be_nil
      expect(example_instance.detail).to be_nil
    end

    it 'updates the appeal with a valid status' do
      example_instance.update_status(status: 'success')

      expect(example_instance.status).to eq('success')
    end

    context 'when incoming and current statuses are different' do
      it 'enqueues the status updated job' do
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'submitted')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 1
      end

      it 'saves code and detail where provided' do
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'error', code: 'code', detail: 'detail')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 1
        expect(AppealsApi::StatusUpdatedJob.jobs.first['args'].first).to include('code' => 'code', 'detail' => 'detail')
      end

      it 'records distinct status updates for each change to the code or detail' do
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 0

        example_instance.update_status(status: 'error', code: 'code', detail: 'detail')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 1
        expect(AppealsApi::StatusUpdatedJob.jobs.last['args'].last).to include('code' => 'code', 'detail' => 'detail')

        example_instance.update_status(status: 'error', code: 'updated-code')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 2
        expect(AppealsApi::StatusUpdatedJob.jobs.last['args'].last).to include('code' => 'updated-code',
                                                                               'detail' => nil)

        example_instance.update_status(status: 'error', detail: 'updated-detail')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 3
        expect(AppealsApi::StatusUpdatedJob.jobs.last['args'].last).to include('code' => nil,
                                                                               'detail' => 'updated-detail')
      end
    end

    context 'when incoming and current statuses are the same' do
      it 'does not enqueues the status updated job' do
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'pending')
        expect(AppealsApi::StatusUpdatedJob.jobs.size).to eq 0
      end
    end

    context "when status has updated to 'submitted' and claimant or veteran email data present" do
      it 'enqueues the appeal received job' do
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'submitted')
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 1
      end
    end

    context "when incoming and current statuses are both 'submitted' and claimant or veteran email data present" do
      before { example_instance.update(status: 'submitted') }

      it 'does not enqueue the appeal received job' do
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'submitted')
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
      end
    end

    context "when incoming status is not 'submitted' and claimant or veteran email data present" do
      it 'does not enqueue the appeal received job' do
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'pending')
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
      end
    end

    context 'when veteran appellant without email provided' do
      it 'gets the ICN and enqueues the appeal received job' do
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
        instance_without_email.update_status(status: 'submitted')
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 1
      end
    end

    context 'when auth_headers are blank' do
      before do
        example_instance.save
        example_instance.update_columns form_data_ciphertext: nil, auth_headers_ciphertext: nil # rubocop:disable Rails/SkipsModelValidations
        example_instance.reload
      end

      it 'does not enqueue the appeal received job' do
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
        example_instance.update_status(status: 'submitted')
        expect(AppealsApi::AppealReceivedJob.jobs.size).to eq 0
      end
    end
  end

  describe '#update_status!' do
    it 'raises given an invalid status' do
      expect do
        example_instance.update_status!(status: 'invalid_status')
      end.to raise_error(ActiveRecord::RecordInvalid,
                         'Validation failed: Status is not included in the list')
    end
  end
end
