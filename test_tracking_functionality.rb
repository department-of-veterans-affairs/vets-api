#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple script to test the tracking functionality without full Rails environment

# Mock the Time class parse method
class Time
  def self.parse(date_str)
    case date_str
    when 'Wed, 07 Sep 2016 00:00:00 EDT'
      Time.new(2016, 9, 7, 4, 0, 0, '+00:00')  # EDT is UTC-4, so 4:00 UTC
    else
      raise ArgumentError, "Invalid date format"
    end
  end
end

# Mock Rails logger
module Rails
  def self.logger
    MockLogger.new
  end
end

class MockLogger
  def warn(message)
    puts "WARN: #{message}"
  end
end

# Mock Vets::Model functionality
module Vets
  module Model
    def self.included(base)
      base.extend(ClassMethods)
    end

    module ClassMethods
      def attribute(name, type, options = {})
        attr_accessor name
        
        # Handle array attributes
        if options[:array] && options[:default]
          define_method("#{name}=") do |value|
            instance_variable_set("@#{name}", value || options[:default])
          end
        end
      end

      def default_sort_by(_options)
        # No-op for testing
      end
    end

    def initialize(attributes = {})
      attributes.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end
  end

  module Type
    class UTCTime
    end
  end

  class Bool
  end
end

# Load our actual code
require_relative 'lib/unified_health_data/models/prescription'
require_relative 'lib/unified_health_data/adapters/vista_prescription_adapter'

# Test data based on the VCR cassette
test_medication = {
  'prescriptionId' => '13650541',
  'prescriptionName' => 'PAROXETINE HCL 30MG TAB',
  'prescriptionNumber' => '2719551',
  'ndcNumber' => '00781171601',
  'refillStatus' => 'active',
  'isRefillable' => true,
  'isTrackable' => true,
  'trackingInfo' => [
    {
      'shippedDate' => 'Wed, 07 Sep 2016 00:00:00 EDT',
      'deliveryService' => 'USPS',
      'trackingNumber' => '657068347565',
      'otherPrescriptionListIncluded' => [
        {
          'prescriptionName' => 'SIROLIMUS 1MG TAB',
          'prescriptionNumber' => '2719536'
        }
      ]
    }
  ]
}

# Test the adapter
adapter = UnifiedHealthData::Adapters::VistaPrescriptionAdapter.new
prescription = adapter.parse(test_medication)

puts "=== Test Results ==="
puts "Prescription ID: #{prescription.id}"
puts "Prescription Name: #{prescription.prescription_name}"
puts "Is Trackable: #{prescription.is_trackable}"
puts "Tracking Array Length: #{prescription.tracking&.length}"

if prescription.tracking && prescription.tracking.length > 0
  tracking_item = prescription.tracking.first
  puts "\n=== First Tracking Item ==="
  puts "Prescription Name: #{tracking_item[:prescriptionName]}"
  puts "Prescription Number: #{tracking_item[:prescriptionNumber]}"
  puts "NDC Number: #{tracking_item[:ndcNumber]}"
  puts "Prescription ID: #{tracking_item[:prescriptionId]}"
  puts "Tracking Number: #{tracking_item[:trackingNumber]}"
  puts "Shipped Date: #{tracking_item[:shippedDate]}"
  puts "Carrier: #{tracking_item[:carrier]}"
  puts "Other Prescriptions: #{tracking_item[:otherPrescriptions]}"
  
  # Verify the format matches requirements
  expected_format = {
    prescriptionName: "PAROXETINE HCL 30MG TAB",
    prescriptionNumber: "2719551",
    ndcNumber: "00781171601", 
    prescriptionId: 13650541,
    trackingNumber: "657068347565",
    shippedDate: "2016-09-07T04:00:00.000Z",
    carrier: "USPS",
    otherPrescriptions: [{prescriptionName: "SIROLIMUS 1MG TAB", prescriptionNumber: "2719536"}]
  }
  
  puts "\n=== Format Verification ==="
  puts "✓ prescriptionName matches: #{tracking_item[:prescriptionName] == expected_format[:prescriptionName]}"
  puts "✓ prescriptionNumber matches: #{tracking_item[:prescriptionNumber] == expected_format[:prescriptionNumber]}"  
  puts "✓ ndcNumber matches: #{tracking_item[:ndcNumber] == expected_format[:ndcNumber]}"
  puts "✓ prescriptionId matches: #{tracking_item[:prescriptionId] == expected_format[:prescriptionId]}"
  puts "✓ trackingNumber matches: #{tracking_item[:trackingNumber] == expected_format[:trackingNumber]}"
  puts "✓ shippedDate matches: #{tracking_item[:shippedDate] == expected_format[:shippedDate]}"
  puts "✓ carrier matches: #{tracking_item[:carrier] == expected_format[:carrier]}"
  puts "✓ otherPrescriptions format matches: #{tracking_item[:otherPrescriptions] == expected_format[:otherPrescriptions]}"
  
  if tracking_item == expected_format
    puts "\n🎉 SUCCESS: Tracking format matches specification exactly!"
  else
    puts "\n❌ MISMATCH: Some fields don't match the expected format"
    puts "Expected: #{expected_format}"
    puts "Actual: #{tracking_item}"
  end
else
  puts "\n❌ ERROR: No tracking data found"
end