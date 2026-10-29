module Sms
  # The provider refused the message for good (e.g. invalid number, recipient opted out).
  class PermanentError < StandardError
    attr_reader :code

    def initialize(message, code: nil)
      super(message)
      @code = code
    end
  end
end
