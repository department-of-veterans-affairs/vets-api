# frozen_string_literal: true

# Shared examples for BGS service error handling
RSpec.shared_examples 'BGS service error handling' do |service_class, method_name, use_instance_double: false|
  bgs_errors = [
    Common::Exceptions::ResourceNotFound,
    Common::Exceptions::ServiceError,
    Common::Exceptions::UnprocessableEntity
  ].freeze

  bgs_errors.each do |bgs_error|
    context "with a #{bgs_error} raised from the BGS service" do
      let(:error_detail) { "Test #{bgs_error.name} detail message" }

      before do
        if use_instance_double
          case service_class.name
          when 'ClaimsApi::PersonWebService'
            allow(person_web_service).to receive(method_name).and_raise(bgs_error, detail: error_detail)
          when 'ClaimsApi::ManageRepresentativeService'
            allow(manage_rep_poa_update_service).to receive(method_name).and_raise(bgs_error, detail: error_detail)
          end
        else
          allow_any_instance_of(service_class).to receive(method_name).and_raise(bgs_error, detail: error_detail)
        end
      end

      it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
        expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)
        expect { subject.new.perform(poa.id) }.to raise_error(bgs_error)
        poa.reload
        expect(poa.status).to eq('errored')
      end

      it 'updates the process status to FAILED and returns the error message' do
        expect { subject.new.perform(poa.id) }.to raise_error(bgs_error)
        process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
        expect(process.step_status).to eq('FAILED')
        expect(process.error_messages.first['title']).to eq('BGS Error')
        expect(process.error_messages.first['detail']).to eq(error_detail)
      end
    end
  end
end

# Shared examples for standard error handling
RSpec.shared_examples 'standard error handling' do |service_class, method_name, use_instance_double: false|
  context 'with a StandardError that is not from the BGS Service' do
    let(:standard_error) { StandardError }

    before do
      if use_instance_double
        case service_class.name
        when 'ClaimsApi::PersonWebService'
          allow(person_web_service).to receive(method_name).and_raise(standard_error)
        when 'ClaimsApi::ManageRepresentativeService'
          allow(manage_rep_poa_update_service).to receive(method_name).and_raise(standard_error)
        end
      else
        allow_any_instance_of(service_class).to receive(method_name).and_raise(standard_error)
      end
    end

    it "updates the form's status and does not create a 'ClaimsApi::PoaVBMSUpdater' job" do
      expect(ClaimsApi::PoaVBMSUpdater).not_to receive(:perform_async)
      expect { subject.new.perform(poa.id) }.to raise_error(standard_error)
      poa.reload
      expect(poa.status).to eq('errored')
    end

    it 'updates the process status to FAILED and returns the error message' do
      expect { subject.new.perform(poa.id) }.to raise_error(standard_error)
      process = ClaimsApi::Process.find_by(processable: poa, step_type: 'POA_UPDATE')
      expect(process.step_status).to eq('FAILED')
      expect(process.error_messages.first['title']).to eq('Generic Error')
      expect(process.error_messages.first['detail']).to eq(standard_error.new.message)
    end
  end
end