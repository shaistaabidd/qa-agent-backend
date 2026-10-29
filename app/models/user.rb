class User < ApplicationRecord
  EMAIL_MAX_LENGTH = 254
  INVITATION_TTL = 7.days
  SIGN_UP_ROLE = "user".freeze
  IMAGE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze
  IMAGE_MAX_SIZE = 5.megabytes
  PROFILE_ATTRIBUTES = %i[first_name last_name].freeze
  PROFILE_ATTRIBUTE_MAX_LENGTH = 255
  # Onboarding steps, in order, and the fields each needs (see User::Onboarding).
  ONBOARDING_STEPS = { step1: %i[first_name last_name], step2: %i[phone] }.freeze

  # Invited users have no password until they accept, and accounts created by
  # Sign in with Google have none at all, so the presence check below replaces
  # the default one.
  has_secure_password validations: false
  has_paper_trail skip: %i[password_digest search_document], ignore: %i[last_sign_in_at updated_at]
  has_one_attached :image

  belongs_to :invited_by, class_name: "User", optional: true
  has_many :sessions, dependent: :delete_all
  has_many :one_time_passwords, dependent: :delete_all

  enum :role, { user: 0, super_admin: 1 }, validate: true

  normalizes :email, :unconfirmed_email, with: -> { it.strip.downcase }
  normalizes(*PROFILE_ATTRIBUTES, with: -> { it.strip.presence })
  # Stored as E.164 ("+12015550123"). Only numbers with a country code are reformatted:
  # without one Phonelib guesses the country, and 2015550123 would become Egyptian.
  normalizes :phone, with: lambda { |raw|
    phone = raw.strip
    phone.start_with?("+") ? Phonelib.parse(phone).e164 : phone.presence
  }

  # Accepting or re-sending an invitation changes these timestamps, which
  # invalidates every token issued before.
  generates_token_for :invitation, expires_in: INVITATION_TTL do
    [invitation_sent_at, invitation_accepted_at]
  end

  validates :email, presence: true, uniqueness: true, length: { maximum: EMAIL_MAX_LENGTH },
                    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :unconfirmed_email, length: { maximum: EMAIL_MAX_LENGTH }, format: { with: URI::MailTo::EMAIL_REGEXP },
                                allow_nil: true
  validate :unconfirmed_email_must_be_available, if: :unconfirmed_email_changed?
  validates :google_uid, uniqueness: true, allow_nil: true
  validate :password_must_be_set, unless: -> { invitation_pending? || google_uid? }
  validates :password, password_strength: true, confirmation: true, allow_nil: true
  validates(*PROFILE_ATTRIBUTES, length: { maximum: PROFILE_ATTRIBUTE_MAX_LENGTH })
  validate :phone_must_be_international, if: :phone?
  validates :image, content_type: IMAGE_CONTENT_TYPES, size: { less_than: IMAGE_MAX_SIZE }

  scope :archived, -> { where.not(archived_at: nil) }
  scope :not_archived, -> { where(archived_at: nil) }
  scope :access_revoked, -> { where.not(access_revoked_at: nil) }
  scope :with_access, -> { where(access_revoked_at: nil) }
  scope :invitation_pending, -> { where.not(invitation_sent_at: nil).where(invitation_accepted_at: nil) }
  scope :joined, -> { where(invitation_sent_at: nil).or(where.not(invitation_accepted_at: nil)) }

  def self.find_by_invitation_token(token)
    user = find_by_token_for(:invitation, token)
    user if user&.invitation_acceptable?
  end

  # The code sent to the new address of an email change still waiting for it.
  def pending_email_confirmation
    one_time_passwords.email_confirmation.first if unconfirmed_email
  end

  def full_name
    [first_name, last_name].compact.join(" ").presence
  end

  # Lets a user be a Flipper actor, so a flag can be switched on for one user
  def flipper_id = "User;#{id}"

  def onboarding = Onboarding.new(self)

  def archived? = archived_at.present?
  def email_verified? = email_verified_at.present?
  def access_revoked? = access_revoked_at.present?
  def invitation_pending? = invitation_sent_at.present? && invitation_accepted_at.nil?
  def invitation_acceptable? = invitation_pending? && !archived? && !access_revoked?
  def can_sign_in? = sign_in_blocked_reason.nil?

  def sign_in_blocked_reason
    if archived? then :archived
    elsif access_revoked? then :access_revoked
    elsif invitation_pending? then :invitation_pending
    end
  end

  # Signs out every other device, so a leaked session dies with the old password.
  def update_password(password:, password_confirmation:, keep_session: nil)
    transaction do
      updated = update(password:, password_confirmation:)
      sessions.where.not(id: keep_session).delete_all if updated
      updated
    end
  end

  # The invitation link was emailed to this address, so accepting it proves the user owns it.
  def accept_invitation(password:, password_confirmation:)
    update(password:, password_confirmation:, invitation_accepted_at: Time.current, email_verified_at: Time.current)
  end

  # A code or link sent to the address came back: the user owns this email.
  def mark_email_verified!
    touch(:email_verified_at) unless email_verified?
  end

  def archive!
    transaction do
      update!(archived_at: Time.current)
      sessions.delete_all
    end
  end

  def unarchive!
    update!(archived_at: nil)
  end

  def revoke_access!
    transaction do
      update!(access_revoked_at: Time.current)
      sessions.delete_all
    end
  end

  def restore_access!
    update!(access_revoked_at: nil)
  end

  private

  def phone_must_be_international
    errors.add(:phone, :invalid) unless phone.start_with?("+") && Phonelib.valid?(phone)
  end

  def unconfirmed_email_must_be_available
    errors.add(:unconfirmed_email, :taken) if unconfirmed_email && User.exists?(email: unconfirmed_email)
  end

  def password_must_be_set
    errors.add(:password, :blank) if password_digest.blank?
  end
end
