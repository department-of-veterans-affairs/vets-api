# frozen_string_literal: true

def stub_medical_copays(method)
  let(:content) { File.read('spec/fixtures/medical_copays/index.json') }

  if method == :index
    before do
      allow_any_instance_of(MedicalCopays::VBS::Service).to receive(:get_copays).and_return(content)
    end
  end
end
