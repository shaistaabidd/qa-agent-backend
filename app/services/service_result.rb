ServiceResult = Data.define(:value, :error) do
  def self.success(value = nil) = new(value:, error: nil)
  def self.failure(error) = new(value: nil, error:)

  def success? = error.nil?
  def failure? = !success?
end
