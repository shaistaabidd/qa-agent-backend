# Copies the Google profile photo onto an account Sign in with Google just
# created. A photo uploaded in the meantime is never replaced.
class AttachGooglePictureJob < ApplicationJob
  queue_as :default

  # The photo is a nicety: a deleted user, a photo Google won't serve, or one our
  # image rules reject is not worth retrying.
  discard_on ActiveRecord::RecordNotFound, GoogleOauth::Error

  def perform(user_id, picture_url)
    user = User.find(user_id)
    return if user.image.attached?

    photo = GoogleOauth::Client.new.picture(picture_url)
    user.update(image: { io: StringIO.new(photo.body), filename: "google-photo", content_type: photo.content_type })
  end
end
