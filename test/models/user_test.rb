require "test_helper"

class UserTest < ActiveSupport::TestCase
  def setup
    @user = create_test_user
  end

  test "should create user with valid attributes" do
    assert @user.valid?
    assert @user.persisted?
  end

  test "should require email" do
    user = User.new(password: "password123", password_confirmation: "password123")
    assert_not user.valid?
  end

  test "should require password" do
    user = User.new(email: "test@example.com")
    assert_not user.valid?
  end

  test "should have unique email" do
    duplicate = User.new(
      email: @user.email,
      password: "password123",
      password_confirmation: "password123"
    )
    assert_not duplicate.valid?
  end

  test "should have customers association" do
    assert_respond_to @user, :customers
  end

  test "should not be google calendar authorized by default" do
    assert_not @user.google_calendar_authorized?
  end

  test "should be authorized with valid token and future expiry" do
    @user.update!(
      google_calendar_token: "test_token",
      google_calendar_expires_at: 1.hour.from_now
    )
    assert @user.google_calendar_authorized?
  end

  test "should not be authorized with expired token" do
    @user.update!(
      google_calendar_token: "test_token",
      google_calendar_expires_at: 1.hour.ago
    )
    assert_not @user.google_calendar_authorized?
  end

  test "should update google calendar auth" do
    auth_hash = {
      "access_token" => "new_token",
      "refresh_token" => "refresh_token",
      "expires_at" => 1.hour.from_now.to_i
    }
    @user.update_google_calendar_auth(auth_hash)
    assert_equal "new_token", @user.google_calendar_token
    assert_equal "refresh_token", @user.google_calendar_refresh_token
  end

  test "should clear google calendar auth" do
    @user.update!(
      google_calendar_token: "token",
      google_calendar_refresh_token: "refresh"
    )
    @user.clear_google_calendar_auth
    assert_nil @user.google_calendar_token
    assert_nil @user.google_calendar_refresh_token
  end

  test "should return session authorization when authorized" do
    @user.update!(
      google_calendar_token: "token",
      google_calendar_refresh_token: "refresh",
      google_calendar_expires_at: 1.hour.from_now
    )
    auth = @user.session_authorization
    assert_equal "token", auth["access_token"]
    assert_equal "refresh", auth["refresh_token"]
  end

  test "should return nil session authorization when not authorized" do
    assert_nil @user.session_authorization
  end
end
