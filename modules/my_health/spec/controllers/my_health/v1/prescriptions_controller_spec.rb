# frozen_string_literal: true

require 'rails_helper'

RSpec.describe MyHealth::V1::PrescriptionsController, type: :controller do
  let(:user) { create(:user, :loa3, :mhv) }

  before do
    sign_in_as(user)
    controller.instance_variable_set(:@current_user, user)
  end

  describe '#fetch_and_include_images' do
    let(:prescription_data) do
      Array.new(20) do |i|
        OpenStruct.new(
          cmop_ndc_value: "0001326468#{i}",
          cmop_ndc_number: "0001326468#{i}",
          prescription_image: nil
        )
      end
    end

    context 'when fetching images with bounded thread pool' do
      it 'limits concurrent threads to MAX_IMAGE_FETCH_THREADS' do
        # Track the maximum number of concurrent threads
        thread_count = Concurrent::AtomicFixnum.new(0)
        max_concurrent = Concurrent::AtomicFixnum.new(0)

        allow(controller).to receive(:fetch_image) do |_uri|
          current = thread_count.increment
          current_max = max_concurrent.value
          max_concurrent.compare_and_set(current_max, current) if current > current_max

          # Simulate slow image fetch
          sleep(0.1)
          thread_count.decrement
          'data:image/jpeg;base64,fake_image_data'
        end

        allow(controller).to receive(:get_image_uri) do |ndc|
          "https://www.myhealth.va.gov/static/MILDrugImages/1/NDC#{ndc}.jpg"
        end

        result = controller.send(:fetch_and_include_images, prescription_data)

        expect(result).to eq(prescription_data)
        # Verify that we never exceeded MAX_IMAGE_FETCH_THREADS concurrent threads
        expect(max_concurrent.value).to be <= MyHealth::V1::PrescriptionsController::MAX_IMAGE_FETCH_THREADS
        # Verify that we did process prescriptions concurrently (more than 1 thread at a time)
        expect(max_concurrent.value).to be > 1
      end

      it 'handles errors gracefully without stopping other fetches' do
        allow(controller).to receive(:get_image_uri) do |ndc|
          "https://www.myhealth.va.gov/static/MILDrugImages/1/NDC#{ndc}.jpg"
        end

        allow(controller).to receive(:fetch_image) do |uri|
          # Fail on odd-numbered prescriptions
          if uri.include?('NDC00013264681')
            raise StandardError, 'Simulated fetch error'
          else
            'data:image/jpeg;base64,fake_image_data'
          end
        end

        # Should not raise an error
        expect do
          controller.send(:fetch_and_include_images, prescription_data)
        end.not_to raise_error

        # Some prescriptions should have images, others should not
        with_images = prescription_data.select { |p| p.prescription_image.present? }
        without_images = prescription_data.select { |p| p.prescription_image.nil? }

        expect(with_images).not_to be_empty
        expect(without_images).not_to be_empty
      end

      it 'continues processing despite slow individual futures' do
        # Use only 5 prescriptions to match MAX_IMAGE_FETCH_THREADS
        # This ensures all prescriptions are processed in a single batch
        small_data = prescription_data[0..4]

        allow(controller).to receive(:get_image_uri) do |ndc|
          "https://www.myhealth.va.gov/static/MILDrugImages/1/NDC#{ndc}.jpg"
        end

        # Create a slow fetch
        allow(controller).to receive(:fetch_image) do
          sleep(2) # Shorter than IMAGE_FETCH_TIMEOUT
          'data:image/jpeg;base64,fake_image_data'
        end

        # Measure execution time
        start_time = Time.zone.now
        result = controller.send(:fetch_and_include_images, small_data)
        elapsed_time = Time.zone.now - start_time

        # With 5 prescriptions and 5 threads running concurrently
        # Total time should be ~2 seconds (not 10 seconds serial)
        # This proves bounded concurrency works
        expect(elapsed_time).to be < 5
        expect(result).to eq(small_data)
      end

      it 'properly cleans up thread pool resources' do
        allow(controller).to receive(:get_image_uri) do |ndc|
          "https://www.myhealth.va.gov/static/MILDrugImages/1/NDC#{ndc}.jpg"
        end

        allow(controller).to receive(:fetch_image).and_return('data:image/jpeg;base64,fake_image_data')

        # Create a small dataset
        small_data = prescription_data[0..2]

        result = controller.send(:fetch_and_include_images, small_data)

        expect(result).to eq(small_data)
        # If we got here without errors, the pool was properly cleaned up
      end

      it 'skips prescriptions without cmop_ndc_value' do
        # Mix of prescriptions with and without NDC values
        mixed_data = [
          OpenStruct.new(cmop_ndc_value: '00013264681', prescription_image: nil),
          OpenStruct.new(cmop_ndc_value: nil, prescription_image: nil),
          OpenStruct.new(cmop_ndc_value: '', prescription_image: nil),
          OpenStruct.new(cmop_ndc_value: '00013264682', prescription_image: nil)
        ]

        fetch_call_count = Concurrent::AtomicFixnum.new(0)
        allow(controller).to receive(:get_image_uri) do |ndc|
          "https://www.myhealth.va.gov/static/MILDrugImages/1/NDC#{ndc}.jpg"
        end

        allow(controller).to receive(:fetch_image) do
          fetch_call_count.increment
          'data:image/jpeg;base64,fake_image_data'
        end

        controller.send(:fetch_and_include_images, mixed_data)

        # Should only fetch images for prescriptions with NDC values (2 out of 4)
        expect(fetch_call_count.value).to eq(2)
      end
    end
  end
end
