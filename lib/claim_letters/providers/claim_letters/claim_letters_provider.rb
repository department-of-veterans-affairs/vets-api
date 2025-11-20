# frozen_string_literal: true

# interface for a ClaimLetterProvider
# `include ClaimLettersProvider` in a new ClaimLetterProvider class
# the new class MUST implement these methods to be a ClaimLetterProvider
module ClaimLettersProvider
  def get_letters = raise(NotImplementedError)
  def get_letter(_id) = raise(NotImplementedError)
end
