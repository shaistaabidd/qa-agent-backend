module Sms
  # What Twilio answered when it took an SMS: its message SID and status.
  Delivery = Data.define(:sid, :status)
end
