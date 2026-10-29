module Sms
  # Sends through Twilio's REST API.
  class TwilioSender
    HTTP_TIMEOUT = 10 # seconds

    def initialize(config = Rails.configuration.x.sms)
      @config = config
    end

    def deliver(to:, body:)
      raise PermanentError, I18n.t("sms.not_configured") unless configured?

      message = client.messages.create(to:, body:, **sender)
      Delivery.new(sid: message.sid, status: message.status)
    rescue Twilio::REST::RestError => e
      raise classify(e)
    rescue Twilio::REST::TwilioError => e
      # Network failure (twilio-ruby wraps Faraday errors in TwilioError).
      raise TransientError, e.message
    end

    private

    def configured?
      sender_set = @config[:from].present? || @config[:messaging_service_sid].present?
      @config[:account_sid].present? && @config[:auth_token].present? && sender_set
    end

    # Twilio-side outages and rate limits are worth retrying; any other refusal is final.
    def classify(error)
      status = error.status_code.to_i
      return TransientError.new(error.message) if status >= 500 || status == 429

      PermanentError.new(error.error_message.presence || error.message, code: error.code&.to_s)
    end

    # A stalled connection must not hold a Sidekiq thread; a timeout is retried like any network error.
    def client
      http = Twilio::HTTP::Client.new(timeout: HTTP_TIMEOUT)
      Twilio::REST::Client.new(@config[:account_sid], @config[:auth_token], nil, nil, http)
    end

    # A Messaging Service picks the sending number itself; otherwise use the configured number.
    def sender
      service = @config[:messaging_service_sid]
      service ? { messaging_service_sid: service } : { from: @config[:from] }
    end
  end
end
