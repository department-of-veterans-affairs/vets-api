# frozen_string_literal: true

module ClaimsApi
  module V2
    class MockDocumentsService
      def generate_documents # rubocop:disable Metrics/MethodLength
        # originally generated with Faker
        [
          {
            "document_id": '{88996436-8462-J234-M927-4D0362UIC83M}',
            "document_type_label": 'VA 21-686c Application Request To Add And/Or Remove Dependents',
            "original_file_name": nil,
            "tracked_item_id": nil,
            "upload_date": 1_666_383_262_000
          },
          {
            "document_id": '{47240649-9326-D427-I996-5O3931JRD51T}',
            "document_type_label": 'VA 21-686c Application Request To Add And/Or Remove Dependents',
            "original_file_name": nil,
            "tracked_item_id": nil,
            "upload_date": nil
          },
          {
            "document_id": '{75664546-6020-X897-O277-2P3366EGR93C}',
            "document_type_label": 'VA 21-674 Report of School Attendance',
            "original_file_name": nil,
            "tracked_item_id": nil,
            "upload_date": nil
          },
          {
            "document_id": '{54793680-3922-C419-R556-9O0521OWY70J}',
            "document_type_label": 'VA 21-686c Application Request To Add And/Or Remove Dependents',
            "original_file_name": nil,
            "tracked_item_id": nil,
            "upload_date": nil
          },
          {
            "document_id": '{33508645-7443-H717-P359-8F9469YUO63J}',
            "document_type_label": 'STR - Medical - Photocopy',
            "original_file_name": nil,
            "tracked_item_id": nil,
            "upload_date": nil
          }
        ].shuffle.sample(rand(0..4))
      end
    end
  end
end
