module AuthenticableUser
  extend ActiveSupport::Concern

  private

  def current_user
    @current_user ||= grab_auth_resource_by(User)
  end

  def token
    @token ||= request.headers['Authorization'].to_s.split.last
  end

  def decoded_token
    return @decoded_token if defined?(@decoded_token)

    @decoded_token = JWT.decode(token, secret_key, true, algorithm: 'HS256').first
  rescue JWT::DecodeError, JWT::ExpiredSignature
    @decoded_token = nil
  end

  def secret_key
    Rails.application.secret_key_base
  end

  def grab_auth_resource_by(klass)
    return nil if token.blank? || decoded_token.nil?

    klass.find_by(id: decoded_token['sub'])
  end
end
