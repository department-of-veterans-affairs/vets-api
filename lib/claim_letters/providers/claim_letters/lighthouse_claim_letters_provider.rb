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
  end

  # transforms the letters for web client
  def get_letters
    response = get_letters_allowed_doc_types
    transform_claim_letters(response.body['data'])
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
    res = @service.claim_letter_download(
      document_uuid:,
      file_number:,
      participant_id: @user.participant_id
    )
    # TODO: #102839 need metadata from Lighthouse for the filename...
    filename = ClaimLetters::Utils::LetterTransformer.filename_with_date(DateTime.now)
    yield res.body, 'application/pdf', 'attachment', filename
  end

  private

  def file_number
    # In staging, some users don't have a participant_id
    # only use file_number if participant_id is not available
    # it needs to be nil/null or else Lighthouse will reject the request for using both
    ClaimLetters::Utils::UserHelper.file_number(@user) if @user.participant_id.blank?
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
