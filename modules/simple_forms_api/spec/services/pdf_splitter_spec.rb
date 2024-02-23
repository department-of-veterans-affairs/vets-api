require 'rails_helper'
require_relative '/Users/donshin/vets-api/modules/simple_forms_api/app/controllers/simple_forms_api/v1/uploads_controller.rb' # replace with your actual ruby file name
#require 'active_model'


describe 'UploadsController' do
  let(:form_id) { '/Users/donshin/vets-api/tmp/vba_40_0247-tmp' }
  let(:uploads_controller) { UploadsController.new }

  after do
    # Clean up generated files
    Dir.glob("#{form_id}_page_*.pdf").each do |file|
      File.delete(file)
    end
  end

  describe '#split_pdf' do
    it 'splits the PDF into single pages' do
      uploads_controller.split_pdf(form_id)

      # Assuming the vba_40_0247-tmp.pdf has 2 pages
      expect(File).to exist("#{form_id}_page_1.pdf")
      expect(File).to exist("#{form_id}_page_2.pdf")
    end
  end
end