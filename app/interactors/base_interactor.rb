class BaseInteractor
  include Interactor

  delegate :params, to: :context

  def current_user
    context&.current_user
  end
end
