# frozen_string_literal: true

require 'rails_helper'
require 'sidekiq/testing'
require 'claims_api/power_of_attorney_pdf_constructor'

Sidekiq::Testing.fake!

RSpec.describe ClaimsApi::PoaFormBuilderJob, type: :job do
  subject { described_class }

  let(:power_of_attorney) { create(:power_of_attorney, :with_full_headers) }

  before do
    Sidekiq::Worker.clear_all
    b64_image = File.read('modules/claims_api/spec/fixtures/signature_b64.txt')
    power_of_attorney.form_data = {
      'recordConcent': true,
      'consentAddressChange': true,
      'consentLimits': ['DRUG ABUSE', 'SICKLE CELL'],
      'signatures': {
        'veteran': b64_image,
        'representative': b64_image
      },
      'veteran': {
        'serviceBranch': 'ARMY',
        'address': {
          'numberAndStreet': '2719 Hyperion Ave',
          'city': 'Los Angeles',
          'state': 'CA',
          'country': 'US',
          'zipFirstFive': '92264'
        },
        'phone': {
          'areaCode': '555',
          'ohoneNumber': '5551337'
        }
      },
      'claimant': {
        'firstName': 'Lillian',
        'middleInitial': 'A',
        'lastName': 'Disney',
        'email': 'lillian@disney.com',
        'relationship': 'Spouse',
        'address': {
          'numberAndStreet': '2688 S Camino Real',
          'city': 'Palm Springs',
          'state': 'CA',
          'country': 'US',
          'zipFirstFive': '92264'
        },
        'phone': {
          'areaCode': '555',
          'ohoneNumber': '5551337'
        }
      },
      'serviceOrganization': {
        'organizationName': 'I Help Vets LLC',
        'address': {
          'numberAndStreet': '2719 Hyperion Ave',
          'city': 'Los Angeles',
          'state': 'CA',
          'country': 'US',
          'zipFirstFive': '92264'
        }
      }
    }
    power_of_attorney.save
  end

  describe 'generating the filled and signed pdf' do
    it 'generates the pdf to match example' do
      expect(ClaimsApi::PowerOfAttorneyPdfConstructor).to receive(:new).with(power_of_attorney.id).and_call_original
      expect_any_instance_of(ClaimsApi::PowerOfAttorneyPdfConstructor).to receive(:fill_pdf).twice.and_call_original
      subject.new.perform(power_of_attorney.id)
    end

    it 'generates the expected pdf' do
      Timecop.freeze(Time.zone.parse('2020-01-01T08:00:00Z'))
      subject.new.perform(power_of_attorney.id)

      path = Rails.root.join('tmp', "#{power_of_attorney.id}_final.pdf")
      expected_path = Rails.root.join('modules', 'claims_api', 'spec', 'fixtures', '2122', 'expected_2122.pdf')

      generated_md5s = pdf_to_md5s(path, power_of_attorney.id)
      expected_md5s = pdf_to_md5s(expected_path, power_of_attorney.id)

      expect(generated_md5s).to eq(expected_md5s)
      File.delete(path) if File.exist?(path)
      Timecop.return
    end
  end

  private

  # Converts PDF at path to array of md5's, one md5 for each page of the document.
  # Problem: Taking an md5 of the PDF itself causes a mis-match between the generated and expected PDFs due to
  # differences in metadata.
  #
  # @param [String] path The path to the PDF
  # @param [String] identifier The unique identifier of the power of attorney
  # @return [[String]] Array of md5's
  def pdf_to_md5s(path, identifier)
    image_paths = pdf_to_image(path, identifier)

    image_paths.map do |image_path|
      md5 = Digest::MD5.hexdigest(File.read(image_path))
      File.delete(image_path) if File.exist?(image_path)
      md5
    end
  end

  # Converts PDF at path to jpg's
  # @param [String] path The path to the PDF
  # @param [String] identifier The unique identifier of the power of attorney
  # @return [[String]] Array of image_paths
  def pdf_to_image(path, identifier)
    pdf = MiniMagick::Image.open(path)
    image_paths = []

    pdf.pages.each_with_index do |page, index|
      output_path = Rails.root.join('tmp', "#{identifier}_#{index}.jpg")
      MiniMagick::Tool::Convert.new do |convert|
        convert.background 'white'
        convert.flatten
        convert.density 100
        convert.quality 50
        convert << page.path
        convert << output_path
      end
      image_paths << output_path
    end

    image_paths
  end
end
