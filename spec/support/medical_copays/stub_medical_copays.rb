# frozen_string_literal: true

def stub_medical_copays(method)
  let(:content) { File.read('spec/fixtures/medical_copays/index.json') }

  case method
  when :index
    before do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(content)
    end
  else
    let!(:service) do
      medical_copay_service = double
      expect(MedicalCopays::VBS::Service).to receive(:new).and_return(medical_copay_service)
      medical_copay_service
    end
    let(:statement_id) { '{93631483-E9F9-44AA-BB55-3552376400D8}' }
    let(:content) { File.read('spec/fixtures/files/error_message.txt') }

    before do
      expect(service).to receive(:get_pdf_statement_by_id).with(statement_id).and_return(content)
    end
  end
end

def stub_medical_copays_show
  let(:content) { File.read('spec/fixtures/medical_copays/show.json') }
  let(:id) { '3fa85f64-5717-4562-b3fc-2c963f66afa6' }
  before do
    allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copay_by_id).and_return(content)
  end
end
