class Current < ActiveSupport::CurrentAttributes
  attribute :session, :ip_address, :user_agent, :email_delivery_id

  delegate :user, to: :session, allow_nil: true

  # The person actually acting: the admin behind an impersonated session.
  def actor
    session&.impersonator || user
  end
end
