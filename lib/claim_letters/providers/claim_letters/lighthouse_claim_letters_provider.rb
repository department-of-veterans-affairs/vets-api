# frozen_string_literal: true

require 'claim_letters/providers/claim_letters/claim_letters_provider'
require 'claim_letters/responses/claim_letters_response'
require 'claim_letters/utils/letter_transformer'
require 'claim_letters/utils/doctype_service'
require 'lighthouse/benefits_documents/service'
require 'claim_letters/utils/user_helper'

class LighthouseClaimLettersProvider
  include ClaimLettersProvider
  include ClaimLetters::Utils::LetterTransformer
  include ClaimLetters::Utils::UserHelper

  def initialize(user, allowed_doctypes = nil)
    @user = user
    @allowed_doctypes = allowed_doctypes || ClaimLetters::DoctypeService.allowed_for_user(user)
    @service = BenefitsDocuments::Service.new(user)
    @letters_metadata_cache = nil
  end

  # transforms the letters for web client
  def get_letters
    response = get_letters_allowed_doc_types
    @letters_metadata_cache = response.body['data'] # Cache the metadata
    transform_claim_letters(@letters_metadata_cache)
  end

  # sends back only the raw response body from Lighthouse with the allowed doc_types set
  def get_letters_allowed_doc_types
    @service.claim_letters_search(
      doc_type_ids: @allowed_doctypes,
      file_number:,
      participant_id: @user.participant_id
    )
  end

  def get_letter(document_uuid)
    # Get the metadata for the letter
    metadata = fetch_letter_metadata(document_uuid)

    # If no metadata found, raise an error or handle gracefully
    unless metadata
      Rails.logger.error("No metadata found for document_uuid: #{document_uuid}")
      raise Common::Exceptions::RecordNotFound, "Letter metadata not found for document_uuid: #{document_uuid}"
    end

    # Download the actual letter content
    res = @service.claim_letter_download(
      document_uuid:,
      file_number:,
      participant_id: @user.participant_id
    )

    # Use the receivedAt date from metadata for the filename
    received_date = if metadata['receivedAt']
                      parsed_date = Time.zone.parse(metadata['receivedAt'])
                      parsed_date || DateTime.now # Fall back if parsing returns nil
                    else
                      DateTime.now
                    end
    filename = ClaimLetters::Utils::LetterTransformer.filename_with_date(received_date)

    # Force the response body to binary encoding before yielding
    binary_data = res.body.force_encoding('BINARY')
    yield binary_data, 'application/pdf', 'attachment', filename
  end

  private

  def file_number
    # In staging, some users don't have a participant_id
    # only use file_number if participant_id is not available
    # it needs to be nil/null or else Lighthouse will reject the request for using both
    ClaimLetters::Utils::UserHelper.file_number(@user) if @user.participant_id.blank?
  end

  def fetch_letter_metadata(document_uuid)
    # Use cached data if available, otherwise fetch it
    letters_data = @letters_metadata_cache || fetch_letters_data

    documents = letters_data&.dig('documents') || []

    # Find the document with matching UUID
    documents.find { |doc| doc['documentUuid'] == document_uuid }
  end

  def fetch_letters_data
    response = get_letters_allowed_doc_types
    @letters_metadata_cache = response.body['data']
  end

  def transform_claim_letters(data)
    claim_letters = data['documents'].map do |letter|
      claim_letter_response(letter)
    end

    claim_letters
      .select { |d| ClaimLetters::Utils::LetterTransformer.allowed?(d.attributes, @allowed_doctypes) }
      .select { |d| ClaimLetters::Utils::LetterTransformer.filter_boa(d.attributes) }
      .sort_by(&:received_at)
      .reverse
  end

  def claim_letter_response(letter)
    doc_type = letter['docTypeId'].to_s
    type_description =
      ClaimLetters::Utils::LetterTransformer.decorate_description(doc_type) || letter['documentTypeLabel']

    received_at = Time.zone.parse(letter['receivedAt']) if letter['receivedAt']
    upload_date = Time.zone.parse(letter['uploadedDateTime']) if letter['uploadedDateTime']

    ClaimLetters::Responses::ClaimLetterResponse.new(
      # Please note:
      # Lighthouse documentUuid != VBMS document_id
      document_id: letter['documentUuid'],
      # Lighthouse sends back series_id as the documentUuid
      series_id: letter['documentUuid'],
      version: nil,
      type_description:,
      type_id: doc_type,
      doc_type:,
      subject: letter['subject'],
      received_at:,
      source: 'Lighthouse Benefits Documents claims-letters/search',
      mime_type: 'application/pdf',
      alt_doc_types: nil,
      restricted: false,
      upload_date:
    )
  end
end
