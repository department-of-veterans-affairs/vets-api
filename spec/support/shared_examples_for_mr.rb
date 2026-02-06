# frozen_string_literal: true

shared_examples 'medical records new eligibility check' do |path, cassette_name|
  context 'when new eligibility check is enabled' do
    before do
      allow(Flipper).to receive(:enabled?).with(:mhv_medical_records_new_eligibility_check).and_return(true)
    end

    context 'Basic User' do
      let(:mhv_account_type) { 'Basic' }

      before do
        allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: false))
        allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
        get path
      end

      include_examples 'for user account level', message: 'You do not have access to medical records'
    end

    context 'Advanced User' do
      let(:mhv_account_type) { 'Advanced' }

      before do
        allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: false))
        allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
        get path
      end

      include_examples 'for user account level', message: 'You do not have access to medical records'
    end

    context 'Premium User' do
      let(:mhv_account_type) { 'Premium' }

      context 'who is a VA patient' do
        before do
          allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: true))
          allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
        end

        it 'responds to GET #index' do
          VCR.use_cassette(cassette_name) do
            get path
          end

          expect(response).to be_successful
        end
      end

      context 'who is NOT a VA patient' do
        before do
          allow_any_instance_of(User).to receive(:mhv_user_account).and_return(OpenStruct.new(patient: false))
          allow_any_instance_of(User).to receive(:mhv_correlation_id).and_return('12345678901')
          get path
        end

        include_examples 'for non va patient user', authorized: false,
                                                    message: 'You do not have access to medical records'
      end
    end
  end
end
